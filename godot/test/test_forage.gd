extends "res://test/framework/test_case.gd"
## Coverage for the HarvestZone store, its tile links, and the ForagePatch stocks of GDD §5.5.
##
## Every expected number below is restated from the specification, never read back out of the
## module under test: the 128/16384/5/640 cardinalities from GDD §4.2 and
## systems_architecture.md §2.2, the five forage rows from §5.5's table, the 80% initial stock
## and the basin-sharing rule from §5.1, the injury chance from REQ-SET-068, and the draw
## discipline from ARCH-RNG-002. Calendar days come from `sim_clock.gd`'s own decoder at real
## midnight ticks, so the regrowth sweep crosses a genuine season boundary rather than
## incrementing an int.
##
## GDD §4.2 never states what catalog `ForagePatch.item_id` is drawn from (see the module
## header), so the ids here are opaque small integers and no test asserts a meaning for them.

const Forage := preload("res://scripts/core/forage.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Rng := preload("res://scripts/core/rng.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")

## GDD §4.2: "Up to 128; tile membership max 16384 total zone links".
const EXPECTED_ZONE_CAPACITY: int = 128
const EXPECTED_LINK_CAPACITY: int = 16384
## GDD §4.2: "5 patches/forest zone"; systems_architecture.md §2.2 ForagePatch length 640.
const EXPECTED_PATCHES_PER_ZONE: int = 5
const EXPECTED_PATCH_CAPACITY: int = 640

## GDD §4.3 ZoneType, restated here rather than read from catalog.gd.
const ZONE_FISH: int = 0
const ZONE_RESERVED_1: int = 1
const ZONE_FORAGE: int = 2
const ZONE_FARM: int = 3
const ZONE_ORCHARD: int = 4
const ZONE_FORESTRY: int = 5
const ZONE_QUARRY: int = 6
const ZONE_STOCKPILE: int = 7
const ZONE_CONSERVATION: int = 8

## GDD §4.3 Season.
const SPRING: int = 0
const SUMMER: int = 1
const AUTUMN: int = 2
const WINTER: int = 3

## §5.5 table order: berries, nuts, mushrooms, herb, roots.
const BERRIES: int = 0
const NUTS: int = 1
const MUSHROOMS: int = 2
const HERB: int = 3
const ROOTS: int = 4

## §5.5 "Patch capacity U" in milli-units, and GDD §5.1's "floor(0.8xcapacity)" initial stocks.
const BERRIES_CAPACITY: int = 300000
const NUTS_CAPACITY: int = 240000
const MUSHROOMS_CAPACITY: int = 180000
const HERB_CAPACITY: int = 160000
const ROOTS_CAPACITY: int = 300000
const BERRIES_INITIAL: int = 240000
const NUTS_INITIAL: int = 192000
const MUSHROOMS_INITIAL: int = 144000
const HERB_INITIAL: int = 128000
const ROOTS_INITIAL: int = 240000

## §5.5: "Sustainable floor 20%K; intensive floor 5%K."
const BERRIES_SUSTAINABLE_FLOOR: int = 60000
const BERRIES_INTENSIVE_FLOOR: int = 15000

## GDD §5.1 landmark tiles, indices worked out by hand from `z*128+x`.
## Forest basin west corner (8,20): 20*128+8 = 2568. (9,20): 2569. (8,21): 2696.
const WEST_BASIN_TILE: int = 2568
const WEST_BASIN_TILE_B: int = 2569
const WEST_BASIN_TILE_C: int = 2696

## GDD §5.1: "A fixed-seed tutorial uses seed 20260905."
const TUTORIAL_SEED: int = 20260905

## sim_clock.gd: "one day as 18000 ticks", first midnight at tick 13500.
const TICKS_PER_DAY: int = 18000
const FIRST_MIDNIGHT_TICK: int = 13500

const NULL_REF: Vector2i = Vector2i(-1, 0)

## GDD §4.3 JobKind and JobState, restated here rather than read from catalog.gd.
const JOB_KIND_FORAGE: int = 4
const CANCELLED_STATE: int = 7

## Decision 0030 §4.7: one claim row per Job row, and the payload arithmetic of R05-QTEST-16.
## 8192 * 1 + 8192 * 7 * 4 + 8192 * 8 = 8192 + 229376 + 65536 = 303104.
const EXPECTED_CLAIM_CAPACITY: int = 8192
const EXPECTED_CLAIM_PAYLOAD_BYTES: int = 303104
## Plus HarvestZone's 128-row int64 pair (2048) and its byte mode column (128).
const EXPECTED_QUOTA_ADDITION_BYTES: int = 305280
## The two release-order columns this implementation adds: 2 * 8192 * 8, counted separately.
const EXPECTED_ORDERING_BUFFER_BYTES: int = 131072

## Decision 0030 §4.6, worked by hand from §5.5's capacity, regrowth and availability columns as
## `min(K - floor(0.8K), floor((K - floor(0.8K)) * r * S / 1000000) + 1000)`, flattened as
## `kind * 4 + season`. Nothing here is read back out of the module under test.
const EXPECTED_AUTOMATIC_ALLOWANCE: Array[int] = [
	0, 8200, 3880, 0,
	0, 1576, 4456, 1864,
	2800, 2080, 5320, 0,
	3560, 4072, 2536, 1512,
	4360, 5200, 6040, 2680,
]
## Their column sums: the four ruled automatic daily quotas, in milli-U/day.
const SPRING_AUTOMATIC_QUOTA: int = 10720
const SUMMER_AUTOMATIC_QUOTA: int = 21128
const AUTUMN_AUTOMATIC_QUOTA: int = 22232
const WINTER_AUTOMATIC_QUOTA: int = 6056
## `sum(K_i)` over §5.5's capacity column: 300+240+180+160+300 U.
const MANUAL_MAX: int = 1180000

## Offset-calendar midnights that open a new season, from `13500 + (day - 2) * 18000`:
## absolute day 13 opens summer, day 25 autumn and day 37 winter.
const SUMMER_MIDNIGHT_TICK: int = 211500
const AUTUMN_MIDNIGHT_TICK: int = 427500
const WINTER_MIDNIGHT_TICK: int = 643500

var _forage: Forage = null
var _jobs: JobsScript = null
var _residents: ResidentsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null


func before_each() -> void:
	"""Build a forage store owning a private entity directory."""
	_forage = Forage.new()


func after_each() -> void:
	"""Drop the store built for the test, and any Job store it owned claims through."""
	_forage = null
	_jobs = null
	_residents = null
	_priorities = null
	_schedule = null


func _use_job_store() -> void:
	"""Rebuild the forage store over a live Job store, so it can own forage claims.

	Claims are indexed by owning Job typed row and validate that Job's reference through one
	directory, so the two stores must share it; Forage adopts the Job store's directory.
	"""
	_residents = ResidentsScript.new()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_residents.needs())
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_forage = Forage.new(null, _jobs)


func _make_job(created_tick: int, remaining_mwu: int = 100) -> Vector2i:
	"""Create one FORAGE job with a stated creation tick and hand back its reference.

	Decision 0017 keeps shared progress in the coordinator alone, so a Job that is going to JOIN
	a party must be created with `remaining_mwu` 0; that is what the parameter is for.
	"""
	var made: JobsScript.OpResult = _jobs.create_job(JOB_KIND_FORAGE, 0, 0, remaining_mwu,
		created_tick)
	assert_true(made.ok, "job creates (error: %s)" % made.error)
	return made.ref


func _job_slot(job_ref: Vector2i) -> int:
	"""The Job typed row a reference names, which is also its claim row."""
	return _jobs.directory().get_typed_row(job_ref)


func _spawn_worker() -> int:
	"""Spawn one mouse with the rows a JobAgent needs, and return its resident slot."""
	var spawned: ResidentsScript.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "resident spawns (error: %s)" % spawned.error)
	var slot: int = spawned.value
	assert_true(_priorities.spawn(slot).ok, "priorities row spawns")
	var template: IntMath.IntResult = _schedule.default_template_id()
	assert_true(_schedule.spawn(slot, template.value).ok, "schedule row spawns")
	assert_true(_schedule.resolve(slot, 8, false).ok, "the work-hour activity resolves")
	assert_true(_jobs.spawn_agent(slot).ok, "job agent spawns")
	return slot


func _slot(zone_ref: Vector2i) -> int:
	"""The HarvestZone row a live zone reference names."""
	return _forage.zone_slot_of(zone_ref).value


func _make_designation(basin: Vector2i) -> Vector2i:
	"""Draw a player designation over an existing basin: created, bound, and therefore Inherit.

	R05-BASIN-002: a designation binds to existing ecological ownership; set_basin() is the only
	binding path this module has, and binding is what moves the default mode from Automatic to
	Inherit.
	"""
	var made: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, 1, 0, false, true)
	assert_true(_forage.set_basin(made.ref, basin).ok, "the designation binds to the basin")
	return made.ref


func _make_automatic_basin(danger: int) -> Vector2i:
	"""A basin left on its Automatic default, whose quota is the seasonal formula."""
	var made: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, danger, 0, false, true)
	_forage.create_patch_set(made.ref, PackedInt32Array([10, 11, 12, 13, 14]))
	return made.ref


func _make_zone(zone_type: int, danger: int, quota_milli: int) -> Vector2i:
	"""Designate one enabled, unprotected zone with a MANUAL daily quota, and hand back its ref.

	Decision 0030 defaults a newly created zone -- which owns itself, and so is a basin -- to
	Automatic, whose limit is the seasonal formula and not the value §4.2 stores. A test that
	wants a specific daily budget therefore supplies it through the manual path R05-QUOTA-020
	defines, which is also what makes the setting survive a season change.
	"""
	var made: Forage.OpResult = _forage.create_zone(zone_type, danger, quota_milli, false, true)
	_forage.set_quota_milli(made.ref, quota_milli, SUMMER)
	return made.ref


func _make_basin(danger: int, quota_milli: int) -> Vector2i:
	"""Designate a FORAGE zone and give it all five §5.5 patches with opaque item ids."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, danger, quota_milli)
	var ids: PackedInt32Array = PackedInt32Array([10, 11, 12, 13, 14])
	_forage.create_patch_set(zone, ids)
	return zone


# --- capacities and the §4.2 row ------------------------------------------------------------------

func test_the_published_capacities_match_the_registry() -> void:
	"""GDD §4.2's 128 zones, 16384 links and 5 patches/zone, and §2.2's 640 patch rows."""
	assert_equal(Forage.HARVEST_ZONE_CAPACITY, EXPECTED_ZONE_CAPACITY, "128 harvest zones")
	assert_equal(Forage.ZONE_LINK_CAPACITY, EXPECTED_LINK_CAPACITY, "16384 total zone links")
	assert_equal(Forage.PATCHES_PER_ZONE, EXPECTED_PATCHES_PER_ZONE, "5 patches per forest zone")
	assert_equal(Forage.FORAGE_PATCH_CAPACITY, EXPECTED_PATCH_CAPACITY, "640 ForagePatch rows")
	assert_equal(Forage.HARVEST_ZONE_CAPACITY,
		EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_HARVEST_ZONE],
		"the directory reserves KIND_HARVEST_ZONE at the same 128 rows")


func test_zone_capacity_refuses_the_one_hundred_and_twenty_ninth_designation() -> void:
	"""GDD §4.2 caps HarvestZone at 128; the 129th refuses instead of overwriting one."""
	for index: int in EXPECTED_ZONE_CAPACITY:
		var made: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, 1, 1000, false, true)
		assert_true(made.ok, "zone %d of 128 is designated" % index)
	assert_equal(_forage.zone_count(), EXPECTED_ZONE_CAPACITY, "128 zones are live")
	var overflow: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, 1, 1000, false, true)
	assert_false(overflow.ok, "the 129th designation is refused")
	assert_equal(String(overflow.error), "CAPACITY_HARVEST_ZONE", "the directory's refusal code")
	assert_equal(overflow.ref, NULL_REF, "a refused designation carries the null reference")
	assert_equal(_forage.zone_count(), EXPECTED_ZONE_CAPACITY, "still exactly 128 zones")


func test_a_freed_zone_slot_is_reused_and_the_old_reference_stops_validating() -> void:
	"""EntityRef generation validation: a destroyed zone's reference never resolves again."""
	var first: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	var destroyed: Forage.OpResult = _forage.destroy_zone(first)
	assert_true(destroyed.ok, "the zone is destroyed")
	var second: Vector2i = _make_zone(ZONE_FORAGE, 2, 2000)
	assert_equal(second.x, first.x, "the freed directory slot is reused")
	assert_false(_forage.zone_slot_of(first).ok, "the stale reference no longer resolves")
	assert_true(_forage.zone_slot_of(second).ok, "the live reference resolves")


func test_destroying_a_zone_twice_is_refused() -> void:
	"""A second destroy refuses rather than clearing whatever row reused the slot."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	assert_true(_forage.destroy_zone(zone).ok, "the first destroy succeeds")
	var again: Forage.OpResult = _forage.destroy_zone(zone)
	assert_false(again.ok, "the second destroy is refused")
	assert_equal(String(again.error), "ZONE_NOT_PRESENT", "with the not-present code")


# --- SET-AMEND-001 §3 / REQ-SET-060: the retired hunting zone --------------------------------------

func test_a_reserved_1_zone_is_refused_before_anything_is_allocated() -> void:
	"""REQ-SET-060: "If a command requests ... a RESERVED_1 zone, then the system shall reject it
	before allocating a job or changing the world"."""
	var made: Forage.OpResult = _forage.create_zone(ZONE_RESERVED_1, 1, 1000, false, true)
	assert_false(made.ok, "the retired hunting zone type is refused")
	assert_equal(String(made.error), "RESERVED_ZONE_TYPE", "with the reserved-type code")
	assert_equal(_forage.zone_count(), 0, "no zone row was written")
	assert_equal(_forage.directory().live_count(EntityDirectory.KIND_HARVEST_ZONE), 0,
		"and no directory slot was allocated")


func test_every_other_zone_type_is_accepted() -> void:
	"""SET-AMEND-001 §3: "keep other explicit enum values unchanged" -- only index 1 is rejected."""
	var accepted: Array[int] = [ZONE_FISH, ZONE_FORAGE, ZONE_FARM, ZONE_ORCHARD, ZONE_FORESTRY,
		ZONE_QUARRY, ZONE_STOCKPILE, ZONE_CONSERVATION]
	for zone_type: int in accepted:
		var made: Forage.OpResult = _forage.create_zone(zone_type, 0, 1000, false, true)
		assert_true(made.ok, "zone type %d is designable" % zone_type)
		assert_equal(_forage.zone_type_of(made.value).value, zone_type, "and stores its type")
	assert_equal(_forage.zone_count(), accepted.size(), "eight live zones, one per active type")


func test_an_unknown_zone_type_is_refused() -> void:
	"""§4.3 numbers ZoneType 0..8; nothing outside that range is storable."""
	var high: Forage.OpResult = _forage.create_zone(9, 0, 1000, false, true)
	assert_false(high.ok, "zone type 9 is refused")
	assert_equal(String(high.error), "INVALID_ZONE_TYPE", "with the invalid-type code")
	var low: Forage.OpResult = _forage.create_zone(-1, 0, 1000, false, true)
	assert_false(low.ok, "a negative zone type is refused")


# --- the §4.2 HarvestZone row ------------------------------------------------------------------------

func test_a_zone_reads_back_every_field_it_was_designated_with() -> void:
	"""§4.2: "type: enum, tiles: packed int32[], danger: int32, quota_milli: int64, protected:
	bool, enabled: bool"."""
	var made: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, 3, 987654321, true, false)
	assert_true(made.ok, "the zone is designated")
	var slot: int = made.value
	assert_equal(_forage.zone_type_of(slot).value, ZONE_FORAGE, "type")
	assert_equal(_forage.zone_danger_of(slot).value, 3, "danger")
	assert_equal(_forage.zone_quota_milli_of(slot).value, 987654321, "quota_milli")
	assert_true(_forage.is_zone_protected(slot), "protected")
	assert_false(_forage.is_zone_enabled(slot), "enabled")
	assert_equal(_forage.tile_count_of(slot).value, 0, "a new zone owns no tiles")


func test_a_danger_band_outside_zero_to_three_is_refused() -> void:
	"""§5.5 names exactly four danger bands: "Danger zones:0 ...;1 ...;2 at 64-96 m;3 beyond 96 m"."""
	var high: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, 4, 1000, false, true)
	assert_false(high.ok, "danger 4 is refused")
	assert_equal(String(high.error), "INVALID_DANGER", "with the invalid-danger code")
	var low: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, -1, 1000, false, true)
	assert_false(low.ok, "a negative danger band is refused")
	assert_equal(_forage.zone_count(), 0, "neither attempt wrote a row")


func test_a_negative_quota_is_refused() -> void:
	"""A negative budget has no meaning; §4.2's empty counter value is 0."""
	var made: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, 0, -1, false, true)
	assert_false(made.ok, "a negative quota is refused")
	assert_equal(String(made.error), "INVALID_QUOTA", "with the invalid-quota code")


func test_the_enabled_and_protected_flags_can_be_set_after_designation() -> void:
	"""Both are §4.2 columns; a stale reference refuses rather than writing a dead row."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 0, 1000)
	assert_true(_forage.set_zone_enabled(zone, false).ok, "the zone is disabled")
	assert_false(_forage.is_zone_enabled(_forage.zone_slot_of(zone).value), "and reads disabled")
	assert_true(_forage.set_zone_protected(zone, true).ok, "the zone is protected")
	assert_true(_forage.is_zone_protected(_forage.zone_slot_of(zone).value), "and reads protected")
	_forage.destroy_zone(zone)
	assert_false(_forage.set_zone_enabled(zone, true).ok, "a stale reference is refused")


# --- HarvestZone.tiles: the 16384-link budget ---------------------------------------------------------

func test_the_tile_index_formula_is_the_gdd_grid() -> void:
	"""GDD §5.1: "Exterior tile index is `z*128+x`" over a 128x128 grid."""
	assert_equal(_forage.tile_index(8, 20).value, WEST_BASIN_TILE, "20*128+8 = 2568")
	assert_equal(_forage.tile_index(127, 127).value, 16383, "the last exterior tile")
	assert_false(_forage.tile_index(128, 0).ok, "x=128 is off the grid")
	assert_false(_forage.tile_index(0, -1).ok, "z=-1 is off the grid")
	assert_false(_forage.is_tile_index(EXPECTED_LINK_CAPACITY), "tile 16384 does not exist")


func test_tile_links_refuse_the_sixteen_thousand_three_hundred_and_eighty_fifth() -> void:
	"""GDD §4.2: "tile membership max 16384 total zone links", counted across ALL zones."""
	var whole_map: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	for tile: int in EXPECTED_LINK_CAPACITY:
		if not _forage.add_tile(whole_map, tile).ok:
			fail("tile %d should link inside the 16384 budget" % tile)
			return
	assert_equal(_forage.link_count(), EXPECTED_LINK_CAPACITY, "the budget is exactly spent")
	var second: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	var overflow: Forage.OpResult = _forage.add_tile(second, WEST_BASIN_TILE)
	assert_false(overflow.ok, "the 16385th link is refused")
	assert_equal(String(overflow.error), "CAPACITY_ZONE_LINK", "with the link-capacity code")
	assert_equal(_forage.link_count(), EXPECTED_LINK_CAPACITY, "and nothing was added")


func test_a_released_link_returns_to_the_budget() -> void:
	"""Removing a tile recycles its link, so the 16384 ceiling is a live count, not a high water."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	assert_true(_forage.add_tile(zone, WEST_BASIN_TILE).ok, "the tile links")
	assert_equal(_forage.link_count(), 1, "one link is spent")
	var removed: Forage.OpResult = _forage.remove_tile(zone, WEST_BASIN_TILE)
	assert_true(removed.ok, "the tile unlinks")
	assert_equal(removed.value, 0, "the zone is left with no tiles")
	assert_equal(_forage.link_count(), 0, "and the link is back in the budget")
	assert_false(_forage.remove_tile(zone, WEST_BASIN_TILE).ok, "removing it twice is refused")


func test_a_zone_refuses_the_same_tile_twice() -> void:
	"""A duplicate link would spend the shared 16384 budget on nothing."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	assert_true(_forage.add_tile(zone, WEST_BASIN_TILE).ok, "the first link is made")
	var repeat: Forage.OpResult = _forage.add_tile(zone, WEST_BASIN_TILE)
	assert_false(repeat.ok, "the duplicate is refused")
	assert_equal(String(repeat.error), "TILE_ALREADY_LINKED", "with the already-linked code")
	assert_equal(_forage.link_count(), 1, "and the budget is untouched")


func test_an_off_grid_tile_is_refused() -> void:
	"""Only the 16384 exterior tiles of §5.1 can be linked."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	var refused: Forage.OpResult = _forage.add_tile(zone, EXPECTED_LINK_CAPACITY)
	assert_false(refused.ok, "tile 16384 is refused")
	assert_equal(String(refused.error), "INVALID_TILE", "with the invalid-tile code")
	assert_false(_forage.add_tile(zone, -1).ok, "a negative tile is refused")


func test_two_zones_may_cover_the_same_tile() -> void:
	"""§5.1 speaks of "all intersecting zones", so a tile carries a LIST of zone links."""
	var first: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	var second: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	assert_true(_forage.add_tile(first, WEST_BASIN_TILE).ok, "the first zone covers the tile")
	assert_true(_forage.add_tile(second, WEST_BASIN_TILE).ok, "the second zone covers it too")
	assert_true(_forage.zone_covers_tile(first, WEST_BASIN_TILE), "the first still covers it")
	assert_true(_forage.zone_covers_tile(second, WEST_BASIN_TILE), "and so does the second")
	var found: int = _count_zones_at_tile(WEST_BASIN_TILE)
	assert_equal(found, 2, "the tile's link list names both zones")
	assert_equal(_forage.link_count(), 2, "two links are spent")


func _count_zones_at_tile(tile: int) -> int:
	"""Walk `WorldTileMaps.zone_link_head`'s list for one tile and count its links."""
	var link: int = _forage.tile_link_head_of(tile).value
	var found: int = 0
	while link != Forage.NO_LINK:
		if _forage.zone_slot_of_link(link).ok:
			found += 1
		link = _forage.next_tile_link(link).value
	return found


func test_destroying_a_zone_releases_every_tile_link_it_held() -> void:
	"""A destroyed designation must not strand links in the shared 16384 budget."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	for tile: int in [WEST_BASIN_TILE, WEST_BASIN_TILE_B, WEST_BASIN_TILE_C]:
		_forage.add_tile(zone, tile)
	assert_equal(_forage.link_count(), 3, "three links are spent")
	var destroyed: Forage.OpResult = _forage.destroy_zone(zone)
	assert_true(destroyed.ok, "the zone is destroyed")
	assert_equal(destroyed.value, 3, "and reports the three links it released")
	assert_equal(_forage.link_count(), 0, "the budget is fully returned")
	assert_equal(_count_zones_at_tile(WEST_BASIN_TILE), 0, "the tile's list is empty again")


func test_zones_intersect_only_when_they_share_a_tile() -> void:
	"""§5.1's sharing rule is stated over "all intersecting zones"; this is that test."""
	var first: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	var second: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	_forage.add_tile(first, WEST_BASIN_TILE)
	_forage.add_tile(second, WEST_BASIN_TILE_B)
	assert_false(_forage.zones_intersect(first, second), "disjoint zones do not intersect")
	_forage.add_tile(second, WEST_BASIN_TILE)
	assert_true(_forage.zones_intersect(first, second), "sharing one tile makes them intersect")
	assert_true(_forage.zones_intersect(second, first), "and the test is symmetric")


# --- ForagePatch: five per forest zone, owner-major -------------------------------------------------

func test_a_forage_zone_holds_at_most_the_five_patches_of_the_table() -> void:
	"""GDD §4.2: "5 patches/forest zone" -- §5.5's berries, nuts, mushrooms, herb and roots."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	for kind: int in EXPECTED_PATCHES_PER_ZONE:
		assert_true(_forage.create_patch(zone, kind, 20 + kind).ok, "patch %d exists" % kind)
	var slot: int = _forage.zone_slot_of(zone).value
	assert_equal(_forage.patch_count_of(slot).value, EXPECTED_PATCHES_PER_ZONE, "five patches")
	var sixth: Forage.OpResult = _forage.create_patch(zone, EXPECTED_PATCHES_PER_ZONE, 25)
	assert_false(sixth.ok, "a sixth kind is refused")
	assert_equal(String(sixth.error), "INVALID_PATCH_KIND", "with the invalid-kind code")
	var repeat: Forage.OpResult = _forage.create_patch(zone, BERRIES, 26)
	assert_false(repeat.ok, "a second patch of the same kind is refused")
	assert_equal(String(repeat.error), "PATCH_ALREADY_PRESENT", "with the already-present code")


func test_patch_rows_are_owner_major_at_zone_slot_times_five() -> void:
	"""systems_architecture.md §2.2's 640 rows are exactly 128 zones x 5 kinds."""
	var zone: Vector2i = _make_basin(1, 1000000)
	var slot: int = _forage.zone_slot_of(zone).value
	for kind: int in EXPECTED_PATCHES_PER_ZONE:
		var row: int = _forage.patch_row_for_zone(zone, kind).value
		assert_equal(row, slot * EXPECTED_PATCHES_PER_ZONE + kind, "row of kind %d" % kind)
		assert_equal(_forage.patch_kind_of_row(row).value, kind, "and the row decodes its kind")


func test_the_six_hundred_and_forty_row_block_holds_every_zone_at_five_patches() -> void:
	"""128 designations x 5 patches fills the ForagePatch store exactly, with no row shared."""
	var seen: Dictionary = {}
	for index: int in EXPECTED_ZONE_CAPACITY:
		var zone: Vector2i = _make_basin(1, 1000)
		for kind: int in EXPECTED_PATCHES_PER_ZONE:
			var row: int = _forage.patch_row_for_zone(zone, kind).value
			seen[row] = true
	assert_equal(seen.size(), EXPECTED_PATCH_CAPACITY, "640 distinct live patch rows")
	assert_false(_forage.is_patch_present(EXPECTED_PATCH_CAPACITY), "row 640 does not exist")
	assert_true(_forage.is_patch_present(EXPECTED_PATCH_CAPACITY - 1), "row 639 does")


func test_initial_patch_stock_is_eighty_percent_of_the_table_capacity() -> void:
	"""GDD §5.1: "forage stocks are floor(0.8xcapacity), including dormant stocks"."""
	var zone: Vector2i = _make_basin(1, 1000000)
	var capacities: Array[int] = [BERRIES_CAPACITY, NUTS_CAPACITY, MUSHROOMS_CAPACITY,
		HERB_CAPACITY, ROOTS_CAPACITY]
	var initials: Array[int] = [BERRIES_INITIAL, NUTS_INITIAL, MUSHROOMS_INITIAL, HERB_INITIAL,
		ROOTS_INITIAL]
	for kind: int in EXPECTED_PATCHES_PER_ZONE:
		var row: int = _forage.patch_row_for_zone(zone, kind).value
		assert_equal(_forage.patch_capacity_milli_of(row).value, capacities[kind],
			"§5.5 capacity of kind %d" % kind)
		assert_equal(_forage.stock_milli_of(row).value, initials[kind],
			"80%% initial stock of kind %d" % kind)
		assert_equal(_forage.harvested_year_milli_of(row).value, 0, "and nothing taken yet")


func test_patches_are_refused_on_a_zone_that_is_not_a_forage_zone() -> void:
	"""§4.2's "forest zone" is read as ZoneType.FORAGE; FORESTRY is the wood-cutting zone."""
	var forestry: Vector2i = _make_zone(ZONE_FORESTRY, 1, 1000)
	var refused: Forage.OpResult = _forage.create_patch(forestry, BERRIES, 10)
	assert_false(refused.ok, "a FORESTRY zone holds no forage patch")
	assert_equal(String(refused.error), "ZONE_TYPE_MISMATCH", "with the type-mismatch code")
	var quarry: Vector2i = _make_zone(ZONE_QUARRY, 1, 1000)
	assert_false(_forage.create_patch(quarry, ROOTS, 14).ok, "nor does a QUARRY zone")


func test_a_patch_set_is_all_or_nothing() -> void:
	"""A partially applied set would leave a basin with stock nobody validated."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	assert_true(_forage.create_patch(zone, MUSHROOMS, 12).ok, "one patch already exists")
	var ids: PackedInt32Array = PackedInt32Array([10, 11, 12, 13, 14])
	var refused: Forage.OpResult = _forage.create_patch_set(zone, ids)
	assert_false(refused.ok, "the set is refused because MUSHROOMS is taken")
	assert_equal(String(refused.error), "PATCH_ALREADY_PRESENT", "with the already-present code")
	var slot: int = _forage.zone_slot_of(zone).value
	assert_equal(_forage.patch_count_of(slot).value, 1, "and no further patch was written")
	var short_ids: PackedInt32Array = PackedInt32Array([10, 11])
	assert_equal(String(_forage.create_patch_set(zone, short_ids).error), "PATCH_SET_SIZE",
		"a set of the wrong size is refused")


func test_a_negative_item_id_is_refused() -> void:
	"""§4.2 leaves `item_id`'s catalog unstated, so only the range is validated."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	var refused: Forage.OpResult = _forage.create_patch(zone, BERRIES, -1)
	assert_false(refused.ok, "a negative item id is refused")
	assert_equal(String(refused.error), "INVALID_ITEM_ID", "with the invalid-item code")
	assert_true(_forage.create_patch(zone, BERRIES, 0).ok, "id 0 is a legitimate compiled id")
	var row: int = _forage.patch_row_for_zone(zone, BERRIES).value
	assert_equal(_forage.patch_item_id_of(row).value, 0, "and reads back")


func test_destroying_a_basin_clears_its_patch_block() -> void:
	"""A reused zone slot must not inherit the previous basin's stock."""
	var zone: Vector2i = _make_basin(1, 1000000)
	var row: int = _forage.patch_row_for_zone(zone, BERRIES).value
	assert_true(_forage.is_patch_present(row), "the patch exists")
	assert_true(_forage.destroy_zone(zone).ok, "the basin is destroyed")
	assert_false(_forage.is_patch_present(row), "its patch row is empty")
	var reused: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	assert_equal(_forage.zone_slot_of(reused).value * EXPECTED_PATCHES_PER_ZONE, row,
		"the next zone takes the same block")
	assert_equal(_forage.patch_count_of(_forage.zone_slot_of(reused).value).value, 0,
		"and starts with no patches")


# --- GDD §5.1: overlapping zones share a basin instead of multiplying it ------------------------------

func test_overlapping_zones_share_one_stock_instead_of_multiplying_it() -> void:
	"""GDD §5.1: "all intersecting zones share its quotas and do not multiply capacity"."""
	var basin: Vector2i = _make_basin(1, 1000000)
	var player_zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000000)
	_forage.add_tile(basin, WEST_BASIN_TILE)
	_forage.add_tile(player_zone, WEST_BASIN_TILE)
	assert_true(_forage.set_basin(player_zone, basin).ok, "the player zone references the basin")
	assert_true(_forage.zones_share_basin(basin, player_zone), "both resolve to one basin")
	var basin_row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_equal(_forage.patch_row_for_zone(player_zone, BERRIES).value, basin_row,
		"and to one patch row")
	assert_true(_forage.harvest(player_zone, BERRIES, 40000, SUMMER, false).ok, "40 U is taken")
	assert_equal(_forage.stock_milli_of(basin_row).value, BERRIES_INITIAL - 40000,
		"the basin's own stock fell by exactly what the other zone took")


func test_a_second_zone_cannot_restart_the_shared_quota() -> void:
	"""The exploit this rule exists to stop: drawing a zone twice to take the basin twice."""
	var basin: Vector2i = _make_basin(1, 100000)
	var player_zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 100000)
	_forage.set_basin(player_zone, basin)
	assert_true(_forage.harvest(basin, BERRIES, 100000, SUMMER, false).ok, "the basin takes 100 U")
	assert_equal(_forage.available_quota_milli(player_zone, SUMMER).value, 0,
		"the second zone inherits the exhausted daily allowance")
	var doubled: Forage.OpResult = _forage.harvest(player_zone, BERRIES, 1, SUMMER, false)
	assert_false(doubled.ok, "and cannot take one more milli-unit")
	assert_equal(String(doubled.error), "QUOTA_REACHED", "with the quota code")
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_equal(_forage.harvested_year_milli_of(row).value, 100000,
		"exactly one quota's worth was ever taken")


func test_a_bound_zone_cannot_be_given_patches_of_its_own() -> void:
	"""Creating a second stock under a bound designation is exactly "multiplying capacity"."""
	var basin: Vector2i = _make_basin(1, 100000)
	var player_zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 100000)
	assert_true(_forage.set_basin(player_zone, basin).ok, "the zone binds to the basin")
	var refused: Forage.OpResult = _forage.create_patch(player_zone, BERRIES, 10)
	assert_false(refused.ok, "it may not create its own berries patch")
	assert_equal(String(refused.error), "ZONE_IS_BOUND", "with the bound-zone code")
	var slot: int = _forage.zone_slot_of(player_zone).value
	assert_equal(_forage.patch_count_of(slot).value, 0, "and owns no patch row")


func test_a_basin_that_already_owns_patches_cannot_be_rebound() -> void:
	"""Re-pointing a stocked basin would strand its stock behind an unreachable row."""
	var first: Vector2i = _make_basin(1, 100000)
	var second: Vector2i = _make_basin(1, 100000)
	var refused: Forage.OpResult = _forage.set_basin(first, second)
	assert_false(refused.ok, "a stocked basin refuses to be rebound")
	assert_equal(String(refused.error), "BASIN_HAS_OWN_PATCHES", "with the own-patches code")
	assert_false(_forage.zones_share_basin(first, second), "the two basins stay separate")


func test_basin_chains_are_refused() -> void:
	"""One hop only, so basin_of(basin_of(z)) can never disagree with basin_of(z)."""
	var basin: Vector2i = _make_basin(1, 100000)
	var middle: Vector2i = _make_zone(ZONE_FORAGE, 1, 100000)
	var tail: Vector2i = _make_zone(ZONE_FORAGE, 1, 100000)
	assert_true(_forage.set_basin(middle, basin).ok, "the middle zone binds to the basin")
	var chained: Forage.OpResult = _forage.set_basin(tail, middle)
	assert_false(chained.ok, "binding to an already-bound zone is refused")
	assert_equal(String(chained.error), "BASIN_CHAIN", "with the chain code")
	assert_true(_forage.set_basin(tail, basin).ok, "binding straight to the basin is allowed")
	assert_true(_forage.zones_share_basin(middle, tail), "and both share it")


func test_a_basin_of_a_different_zone_type_is_refused() -> void:
	"""A FORAGE designation cannot draw its stock from a FISH basin."""
	var fish: Vector2i = _make_zone(ZONE_FISH, 1, 100000)
	var forage_zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 100000)
	var refused: Forage.OpResult = _forage.set_basin(forage_zone, fish)
	assert_false(refused.ok, "the cross-type binding is refused")
	assert_equal(String(refused.error), "ZONE_TYPE_MISMATCH", "with the type-mismatch code")


func test_a_new_zone_is_its_own_basin() -> void:
	"""There is no unbound state to forget about: every zone starts self-referencing."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 100000)
	var slot: int = _forage.zone_slot_of(zone).value
	assert_equal(_forage.basin_ref_of(slot), zone, "the basin reference is the zone itself")
	assert_equal(_forage.basin_slot_of(zone).value, slot, "and resolves to its own row")
	assert_true(_forage.zones_share_basin(zone, zone), "a zone trivially shares with itself")


func test_a_zone_whose_basin_was_destroyed_refuses_rather_than_resolving() -> void:
	"""Generation validation on the basin reference, not just on the zone reference."""
	var basin: Vector2i = _make_basin(1, 100000)
	var player_zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 100000)
	_forage.set_basin(player_zone, basin)
	assert_true(_forage.destroy_zone(basin).ok, "the basin is destroyed")
	var resolved: IntMath.IntResult = _forage.basin_slot_of(player_zone)
	assert_false(resolved.ok, "the orphaned zone refuses to resolve a basin")
	assert_equal(resolved.error, "ZONE_NOT_PRESENT", "with the not-present code")
	assert_false(_forage.harvest(player_zone, BERRIES, 1000, SUMMER, false).ok,
		"and cannot harvest through it")


func test_the_effective_quota_is_the_stricter_of_the_zone_and_its_basin() -> void:
	"""Decision 0030: both limits are enforced against their own totals, so the stricter binds.

	Rewritten from the superseded `effective_quota_milli()`, which took `min(basin, zone)` of the
	two stored values. The ruled formula is `max(0, min(Q_b - H_b - R_b, Q_z - H_z - R_z))`; with
	nothing collected or reserved it reduces to the same minimum, which is what is asserted here.
	"""
	var basin: Vector2i = _make_basin(1, 30000)
	var generous: Vector2i = _make_zone(ZONE_FORAGE, 1, 90000)
	_forage.set_basin(generous, basin)
	assert_equal(_forage.available_quota_milli(generous, SUMMER).value, 30000,
		"the basin's is stricter")
	var mean: Vector2i = _make_zone(ZONE_FORAGE, 1, 5000)
	_forage.set_basin(mean, basin)
	assert_equal(_forage.available_quota_milli(mean, SUMMER).value, 5000,
		"the zone's own is stricter")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 30000,
		"a basin measures against itself alone")


# --- §5.5 seasonal availability -------------------------------------------------------------------------

func test_seasonal_availability_matches_the_gdd_table() -> void:
	"""§5.5's Spring/Summer/Autumn/Winter columns, restated row for row."""
	var table: Array[int] = [
		0, 1000, 400, 0,
		0, 200, 1200, 300,
		500, 300, 1200, 0,
		1000, 1200, 600, 200,
		800, 1000, 1200, 400,
	]
	for kind: int in EXPECTED_PATCHES_PER_ZONE:
		for season: int in 4:
			var expected: int = table[kind * 4 + season]
			assert_equal(_forage.availability_per_1000(kind, season).value, expected,
				"availability of kind %d in season %d" % [kind, season])


func test_availability_refuses_an_unknown_kind_or_season() -> void:
	"""§4.3 numbers exactly four seasons and §5.5 exactly five forage rows."""
	assert_false(_forage.availability_per_1000(EXPECTED_PATCHES_PER_ZONE, SUMMER).ok,
		"kind 5 does not exist")
	assert_false(_forage.availability_per_1000(BERRIES, 4).ok, "season 4 does not exist")
	assert_false(_forage.availability_per_1000(BERRIES, -1).ok, "nor does a negative season")


func test_dormant_kinds_are_exactly_the_zero_columns() -> void:
	"""§5.5: "unavailable patches become dormant, not destroyed"."""
	assert_true(_forage.is_dormant(BERRIES, SPRING), "berries are dormant in spring")
	assert_true(_forage.is_dormant(BERRIES, WINTER), "and in winter")
	assert_true(_forage.is_dormant(NUTS, SPRING), "nuts are dormant in spring")
	assert_true(_forage.is_dormant(MUSHROOMS, WINTER), "mushrooms are dormant in winter")
	assert_false(_forage.is_dormant(ROOTS, WINTER), "roots are not: winter availability is 400")
	assert_false(_forage.is_dormant(HERB, WINTER), "nor is herb: winter availability is 200")


func test_a_dormant_patch_refuses_harvest_but_keeps_its_stock() -> void:
	"""§5.5: dormant, "not destroyed" -- the stock is still there when the season turns."""
	var basin: Vector2i = _make_basin(1, 1000000)
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	var refused: Forage.OpResult = _forage.harvest(basin, BERRIES, 1000, WINTER, false)
	assert_false(refused.ok, "berries cannot be harvested in winter")
	assert_equal(String(refused.error), "PATCH_DORMANT", "with the dormant code")
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_INITIAL, "the stock is intact")
	assert_true(_forage.harvest(basin, BERRIES, 1000, SUMMER, false).ok, "and summer harvests it")


func test_winter_stock_is_harvested_where_availability_is_positive() -> void:
	"""§5.5: "Winter stock can be harvested where availability>0"."""
	var basin: Vector2i = _make_basin(1, 1000000)
	var roots_row: int = _forage.patch_row_for_zone(basin, ROOTS).value
	var taken: Forage.OpResult = _forage.harvest(basin, ROOTS, 5000, WINTER, false)
	assert_true(taken.ok, "roots harvest in winter at availability 400")
	assert_equal(taken.value, ROOTS_INITIAL - 5000, "and the stock falls by exactly that")
	assert_true(_forage.harvest(basin, HERB, 5000, WINTER, false).ok, "herb too, at 200")
	assert_equal(_forage.stock_milli_of(roots_row).value, ROOTS_INITIAL - 5000, "roots stock")
	assert_false(_forage.harvest(basin, MUSHROOMS, 1000, WINTER, false).ok,
		"mushrooms do not, at 0")


# --- §5.5 regrowth ----------------------------------------------------------------------------------------

func test_daily_regrowth_matches_the_stated_formula() -> void:
	"""§5.5: "Daily regrowth=floor((K-P)*r*season/1000000)".

	Berries in summer: K-P = 60000, r = 120, season = 1000, so 60000*120*1000/1000000 = 7200.
	Nuts in autumn: K-P = 48000, r = 60, season = 1200, so 48000*60*1200/1000000 = 3456.
	"""
	var basin: Vector2i = _make_basin(1, 1000000)
	var berries_row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_equal(_forage.daily_regrowth_milli(berries_row, SUMMER).value, 7200, "berries, summer")
	var grown: Forage.OpResult = _forage.regrow_patch(berries_row, SUMMER)
	assert_true(grown.ok, "the patch grows")
	assert_equal(grown.value, BERRIES_INITIAL + 7200, "to 247200 milli-U")
	var nuts_row: int = _forage.patch_row_for_zone(basin, NUTS).value
	assert_equal(_forage.daily_regrowth_milli(nuts_row, AUTUMN).value, 3456, "nuts, autumn")
	assert_equal(_forage.regrow_patch(nuts_row, AUTUMN).value, NUTS_INITIAL + 3456, "to 195456")


func test_regrowth_applies_the_one_unit_minimum() -> void:
	"""§5.5: "plus a minimum 1 U when season>0 and P<K".

	Herb in winter: K-P = 32000, r = 80, season = 200, so the formula gives 512 -- below one
	unit, so the patch grows exactly 1000 milli-U instead.
	"""
	var basin: Vector2i = _make_basin(1, 1000000)
	var row: int = _forage.patch_row_for_zone(basin, HERB).value
	assert_equal(_forage.daily_regrowth_milli(row, WINTER).value, 1000, "the 1 U floor applies")
	assert_equal(_forage.regrow_patch(row, WINTER).value, HERB_INITIAL + 1000, "so herb gains 1 U")


func test_a_dormant_patch_does_not_regrow() -> void:
	"""§5.5 conditions both the formula and its minimum on the season multiplier."""
	var basin: Vector2i = _make_basin(1, 1000000)
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_equal(_forage.daily_regrowth_milli(row, WINTER).value, 0, "no winter berry regrowth")
	var grown: Forage.OpResult = _forage.regrow_patch(row, WINTER)
	assert_true(grown.ok, "a dormant patch is not an error")
	assert_equal(grown.value, BERRIES_INITIAL, "and its stock is unchanged")


func test_regrowth_never_carries_a_patch_above_its_capacity() -> void:
	"""The 1 U minimum can exceed the room left; the increment is clamped to K-P (module header).

	Herb in winter gains exactly 1 U/day. After taking 1500 milli-U the room is 33500, so 33
	days leave 500 -- and the 34th day grows 500, not 1000.
	"""
	var basin: Vector2i = _make_basin(1, 1000000)
	var row: int = _forage.patch_row_for_zone(basin, HERB).value
	assert_true(_forage.harvest(basin, HERB, 1500, WINTER, false).ok, "1.5 U is taken")
	for _day: int in 33:
		_forage.regrow_patch(row, WINTER)
	assert_equal(_forage.stock_milli_of(row).value, HERB_CAPACITY - 500, "500 milli-U of room")
	assert_equal(_forage.daily_regrowth_milli(row, WINTER).value, 500, "the last day is clamped")
	assert_equal(_forage.regrow_patch(row, WINTER).value, HERB_CAPACITY, "the patch is full")
	assert_equal(_forage.daily_regrowth_milli(row, WINTER).value, 0, "and grows no further")


func test_the_daily_sweep_grows_every_live_patch_of_every_basin() -> void:
	"""ARCH-SYS-005 owns the midnight call; this is the sweep it will make."""
	var first: Vector2i = _make_basin(1, 1000000)
	var second: Vector2i = _make_basin(2, 1000000)
	var swept: Forage.OpResult = _forage.regrow_daily(SUMMER)
	assert_true(swept.ok, "the sweep runs")
	assert_equal(swept.value, 10, "ten patches grow: two basins x five available summer kinds")
	assert_equal(_forage.stock_milli_of(_forage.patch_row_for_zone(first, BERRIES).value).value,
		BERRIES_INITIAL + 7200, "the first basin's berries grew")
	assert_equal(_forage.stock_milli_of(_forage.patch_row_for_zone(second, BERRIES).value).value,
		BERRIES_INITIAL + 7200, "and so did the second's")
	assert_equal(_forage.regrow_daily(SPRING).value, 6,
		"a spring sweep skips the two kinds §5.5 makes dormant then")
	assert_false(_forage.regrow_daily(4).ok, "an unknown season is refused")


func test_regrowth_across_real_calendar_days_waits_for_the_season_to_turn() -> void:
	"""GDD §5.1: 12-day seasons from year 1/spring/day 1, first midnight at tick 13500.

	Berries have spring availability 0, so the eleven midnights inside spring grow nothing and
	the twelfth -- the crossing into absolute day 13, summer -- grows the full 7200.
	"""
	var basin: Vector2i = _make_basin(1, 1000000)
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	var summer_days: int = 0
	for boundary: int in 12:
		var when: SimClock.Calendar = SimClock.Calendar.new(
			FIRST_MIDNIGHT_TICK + boundary * TICKS_PER_DAY)
		if when.season == SUMMER:
			summer_days += 1
		_forage.regrow_daily(when.season)
	assert_equal(summer_days, 1, "exactly one of the twelve midnights lands in summer")
	assert_equal(SimClock.Calendar.new(FIRST_MIDNIGHT_TICK + 11 * TICKS_PER_DAY).absolute_day, 13,
		"the twelfth midnight opens absolute day 13")
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_INITIAL + 7200,
		"berries grew on exactly that one day")


# --- §5.5 protection floors, REQ-SET-069 quota stop --------------------------------------------------------

func test_the_sustainable_floor_is_twenty_percent_of_capacity() -> void:
	"""§5.5: "Sustainable floor 20%K"."""
	var basin: Vector2i = _make_basin(1, 1000000)
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_equal(_forage.harvest_floor_milli(row, false).value, BERRIES_SUSTAINABLE_FLOOR,
		"60000 milli-U of 300000")
	var to_floor: int = BERRIES_INITIAL - BERRIES_SUSTAINABLE_FLOOR
	assert_true(_forage.harvest(basin, BERRIES, to_floor, SUMMER, false).ok, "180 U comes off")
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_SUSTAINABLE_FLOOR, "down to the floor")
	var below: Forage.OpResult = _forage.harvest(basin, BERRIES, 1, SUMMER, false)
	assert_false(below.ok, "and not one milli-unit further")
	assert_equal(String(below.error), "BELOW_HARVEST_FLOOR", "with the floor code")


func test_the_intensive_floor_is_five_percent_of_capacity() -> void:
	"""§5.5: "intensive floor 5%K" -- deeper, and still a floor."""
	var basin: Vector2i = _make_basin(1, 1000000)
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_equal(_forage.harvest_floor_milli(row, true).value, BERRIES_INTENSIVE_FLOOR,
		"15000 milli-U of 300000")
	var to_floor: int = BERRIES_INITIAL - BERRIES_INTENSIVE_FLOOR
	assert_true(_forage.harvest(basin, BERRIES, to_floor, SUMMER, true).ok, "225 U comes off")
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_INTENSIVE_FLOOR, "down to 5%")
	assert_false(_forage.harvest(basin, BERRIES, 1, SUMMER, true).ok, "and no further")


func test_harvestable_reports_what_the_floor_and_quota_actually_allow() -> void:
	"""The number a reservation gate needs: stock above the floor, capped by the shared quota."""
	var basin: Vector2i = _make_basin(1, 50000)
	assert_equal(_forage.harvestable_milli(basin, BERRIES, SUMMER, false).value, 50000,
		"the quota binds below the 180000 the floor would allow")
	assert_equal(_forage.harvestable_milli(basin, BERRIES, WINTER, false).value, 0,
		"a dormant patch offers nothing")
	var rich: Vector2i = _make_basin(1, 1000000)
	assert_equal(_forage.harvestable_milli(rich, BERRIES, SUMMER, false).value, 180000,
		"otherwise the sustainable floor binds")
	assert_equal(_forage.harvestable_milli(rich, BERRIES, SUMMER, true).value, 225000,
		"and the intensive floor allows more")


func test_a_reached_quota_stops_further_harvest() -> void:
	"""REQ-SET-069: "If a forage quota ... is reached, then the system shall stop new
	reservations and retain already collected cargo for hauling"."""
	var basin: Vector2i = _make_basin(1, 50000)
	assert_false(_forage.is_quota_reached(basin, SUMMER), "the quota starts unspent")
	assert_true(_forage.harvest(basin, BERRIES, 30000, SUMMER, false).ok, "30 U is taken")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 20000, "20 U remains")
	var over: Forage.OpResult = _forage.harvest(basin, BERRIES, 25000, SUMMER, false)
	assert_false(over.ok, "a 25 U request over a 20 U remainder is refused, not clamped")
	assert_equal(String(over.error), "QUOTA_REACHED", "with the quota code")
	assert_true(_forage.harvest(basin, BERRIES, 20000, SUMMER, false).ok, "20 U exactly fits")
	assert_true(_forage.is_quota_reached(basin, SUMMER), "and the quota is now reached")


func test_a_zero_quota_permits_nothing() -> void:
	"""The document states no "unlimited" encoding, so 0 is read as a zero budget."""
	var basin: Vector2i = _make_basin(1, 0)
	assert_true(_forage.is_quota_reached(basin, SUMMER), "a zero quota is reached immediately")
	var refused: Forage.OpResult = _forage.harvest(basin, BERRIES, 1, SUMMER, false)
	assert_false(refused.ok, "and nothing can be taken")
	assert_equal(String(refused.error), "QUOTA_REACHED", "with the quota code")


func test_the_year_accumulator_is_reset_by_its_owner_and_is_not_the_quota() -> void:
	"""Decision 0030: `harvested_year_milli` is annual history, NOT the quota accumulator.

	CHANGED. This test used to assert that resetting the year total "opens the quota again",
	which was true only of the superseded annual per-patch enforcement. The ruled quota is daily
	and lives on HarvestZone, so a year boundary must leave it exactly where it was; run_midnight()
	is the only thing that reopens it.
	"""
	var basin: Vector2i = _make_basin(1, 50000)
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	_forage.harvest(basin, BERRIES, 50000, SUMMER, false)
	assert_equal(_forage.harvested_year_milli_of(row).value, 50000, "50 U was taken this year")
	_forage.reset_harvested_year()
	assert_equal(_forage.harvested_year_milli_of(row).value, 0, "the year total is cleared")
	assert_true(_forage.is_quota_reached(basin, SUMMER),
		"and today's spent quota is NOT reopened by a year boundary")
	assert_equal(_forage.harvested_today_milli_of(_forage.zone_slot_of(basin).value).value, 50000,
		"the daily collected total is untouched by the annual reset")
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_INITIAL - 50000,
		"and the stock is not refilled by a new year")


func test_a_protected_zone_refuses_automatic_harvest() -> void:
	"""§5.5: "Protected tiles are never automatically harvested"."""
	var basin: Vector2i = _make_basin(1, 1000000)
	assert_true(_forage.set_zone_protected(basin, true).ok, "the zone is protected")
	var refused: Forage.OpResult = _forage.harvest(basin, BERRIES, 1000, SUMMER, false)
	assert_false(refused.ok, "no automatic harvest crosses a protected zone")
	assert_equal(String(refused.error), "ZONE_PROTECTED", "with the protected code")
	_forage.set_zone_protected(basin, false)
	assert_true(_forage.harvest(basin, BERRIES, 1000, SUMMER, false).ok, "unprotecting reopens it")


func test_a_disabled_zone_refuses_harvest() -> void:
	"""§4.2's `enabled` flag is the designation's own on/off switch."""
	var basin: Vector2i = _make_basin(1, 1000000)
	_forage.set_zone_enabled(basin, false)
	var refused: Forage.OpResult = _forage.harvest(basin, BERRIES, 1000, SUMMER, false)
	assert_false(refused.ok, "a disabled zone harvests nothing")
	assert_equal(String(refused.error), "ZONE_DISABLED", "with the disabled code")


func test_harvest_refuses_a_non_positive_amount() -> void:
	"""A zero or negative debit would let a job book cargo the basin never released."""
	var basin: Vector2i = _make_basin(1, 1000000)
	assert_false(_forage.harvest(basin, BERRIES, 0, SUMMER, false).ok, "zero is refused")
	var negative: Forage.OpResult = _forage.harvest(basin, BERRIES, -1000, SUMMER, false)
	assert_false(negative.ok, "a negative amount is refused")
	assert_equal(String(negative.error), "INVALID_AMOUNT", "with the invalid-amount code")
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_INITIAL, "and the stock is untouched")


func test_the_non_allocating_harvest_form_debits_the_same_shared_stock() -> void:
	"""AGENTS.md: "No allocation on hot paths. Use the `_into(a, b, out) -> bool` forms"."""
	var basin: Vector2i = _make_basin(1, 1000000)
	var player_zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000000)
	_forage.set_basin(player_zone, basin)
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_forage.harvest_into(player_zone, BERRIES, 25000, SUMMER, false, out),
		"25 U comes off through the bound zone")
	assert_equal(out.value, BERRIES_INITIAL - 25000, "and the remaining stock is reported")
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_INITIAL - 25000,
		"on the basin's own row")
	assert_false(_forage.harvest_into(basin, BERRIES, 1, WINTER, false, out),
		"a dormant season refuses through the same form")
	assert_equal(out.error, "PATCH_DORMANT", "with the dormant code")
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_INITIAL - 25000,
		"and a refusal debits nothing")


func test_harvest_refuses_a_kind_the_basin_has_no_patch_for() -> void:
	"""A missing patch refuses; it does not silently yield nothing."""
	var zone: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000000)
	_forage.create_patch(zone, BERRIES, 10)
	var refused: Forage.OpResult = _forage.harvest(zone, NUTS, 1000, AUTUMN, false)
	assert_false(refused.ok, "there is no nuts patch")
	assert_equal(String(refused.error), "PATCH_NOT_PRESENT", "with the not-present code")


# --- §5.5 work per U -----------------------------------------------------------------------------------------

func test_work_per_u_matches_the_stated_formula() -> void:
	"""§5.5: `ceil(base_work*1000000/((1000+40*FORAGE_level)*(1000+100*natural_danger)))`.

	Herb, base 8: level 0/danger 0 -> ceil(8000000/1000000) = 8; level 0/danger 3 ->
	ceil(8000000/1300000) = 7; level 5/danger 0 -> ceil(8000000/1200000) = 7; level 5/danger 3 ->
	ceil(8000000/1560000) = 6.
	"""
	assert_equal(_forage.work_per_u(HERB, 0, 0).value, 8, "herb, unskilled, safe")
	assert_equal(_forage.work_per_u(HERB, 0, 3).value, 7, "danger 3 yields more per unit of work")
	assert_equal(_forage.work_per_u(HERB, 5, 0).value, 7, "skill does the same")
	assert_equal(_forage.work_per_u(HERB, 5, 3).value, 6, "and they compound")
	assert_equal(_forage.work_per_u(BERRIES, 10, 3).value, 3, "berries: ceil(4000000/1820000)")
	assert_equal(_forage.work_per_u(ROOTS, 10, 0).value, 5, "roots: ceil(6000000/1400000)")
	assert_equal(_forage.work_per_u(MUSHROOMS, 0, 3).value, 4, "mushrooms: ceil(5000000/1300000)")


func test_work_per_u_refuses_arguments_outside_the_stated_domains() -> void:
	"""Five forage rows, danger bands 0..3, and no negative skill level."""
	assert_false(_forage.work_per_u(EXPECTED_PATCHES_PER_ZONE, 0, 0).ok, "kind 5 does not exist")
	assert_false(_forage.work_per_u(BERRIES, -1, 0).ok, "a negative FORAGE level is refused")
	var over: IntMath.IntResult = _forage.work_per_u(BERRIES, 0, 4)
	assert_false(over.ok, "danger 4 is refused")
	assert_equal(over.error, "INVALID_DANGER", "with the invalid-danger code")


func test_natural_danger_is_read_from_the_basin_not_the_designation() -> void:
	"""§5.5: natural danger is "the basin center's distance category ... fixed at generation"."""
	var basin: Vector2i = _make_basin(3, 1000000)
	var player_zone: Vector2i = _make_zone(ZONE_FORAGE, 0, 1000000)
	_forage.set_basin(player_zone, basin)
	assert_equal(_forage.natural_danger_of(player_zone).value, 3, "the basin's band, not the 0")
	assert_equal(_forage.zone_danger_of(_forage.zone_slot_of(player_zone).value).value, 0,
		"the designation keeps its own hazard band")
	assert_equal(_forage.natural_danger_of(basin).value, 3, "and the basin agrees with itself")


# --- REQ-SET-067 consent, REQ-SET-068 injury roll ---------------------------------------------------------------

func test_dangerous_work_permission_is_required_at_danger_two_and_three() -> void:
	"""REQ-SET-067: "While a forage zone has danger 2 or 3, the system shall require the
	resident's dangerous-work permission"."""
	var safe: Vector2i = _make_zone(ZONE_FORAGE, 1, 1000)
	assert_false(_forage.requires_dangerous_work(safe), "danger 1 needs no permission")
	assert_true(_forage.check_worker_permitted(safe, false).ok, "so an unwilling worker may go")
	var risky: Vector2i = _make_zone(ZONE_FORAGE, 2, 1000)
	assert_true(_forage.requires_dangerous_work(risky), "danger 2 does")
	var refused: Forage.OpResult = _forage.check_worker_permitted(risky, false)
	assert_false(refused.ok, "and an unwilling worker is refused")
	assert_equal(String(refused.error), "DANGEROUS_WORK_REFUSED", "with the consent code")
	assert_true(_forage.check_worker_permitted(risky, true).ok, "a consenting worker may go")
	assert_true(_forage.requires_dangerous_work(_make_zone(ZONE_FORAGE, 3, 1000)), "danger 3 too")


func test_the_injury_chance_matches_the_requirement() -> void:
	"""REQ-SET-068: chance `max(1,8*danger-FORAGE_level)` per 10000."""
	assert_equal(_forage.injury_chance_per_10000(1, 0).value, 8, "danger 1, level 0")
	assert_equal(_forage.injury_chance_per_10000(2, 0).value, 16, "danger 2, level 0")
	assert_equal(_forage.injury_chance_per_10000(3, 0).value, 24, "danger 3, level 0")
	assert_equal(_forage.injury_chance_per_10000(2, 5).value, 11, "skill lowers it")
	assert_equal(_forage.injury_chance_per_10000(1, 10).value, 1, "and the floor is 1, not 0")
	assert_equal(_forage.injury_chance_per_10000(3, 24).value, 1, "even at exactly zero")
	assert_false(_forage.injury_chance_per_10000(4, 0).ok, "danger 4 is refused")


func test_the_injury_constants_are_the_ones_the_requirement_states() -> void:
	"""REQ-SET-068: "causing 10 health loss and severity 1 injury on success"; segments are 60 WU."""
	assert_equal(Forage.INJURY_HEALTH_LOSS, 10, "10 health")
	assert_equal(Forage.INJURY_SEVERITY, 1, "severity 1")
	assert_equal(Forage.EXPOSURE_SEGMENT_WU, 60, "60 WU per exposure segment")
	assert_equal(Forage.INJURY_ROLL_DENOMINATOR, 10000, "the chance is per 10000")


func test_completed_segments_count_whole_sixty_wu_crossings() -> void:
	"""ARCH-RNG-002: "One hazard roll after each completed 60 WU exposure segment"."""
	assert_equal(_forage.completed_exposure_segments(0, 59).value, 0, "59 WU completes nothing")
	assert_equal(_forage.completed_exposure_segments(0, 60).value, 1, "60 WU completes one")
	assert_equal(_forage.completed_exposure_segments(60, 119).value, 0, "no boundary crossed")
	assert_equal(_forage.completed_exposure_segments(59, 60).value, 1, "one boundary crossed")
	assert_equal(_forage.completed_exposure_segments(0, 130).value, 2, "130 WU completes two")
	assert_false(_forage.completed_exposure_segments(100, 60).ok, "work cannot run backwards")
	assert_false(_forage.completed_exposure_segments(-1, 60).ok, "nor start negative")


func test_the_forage_stream_advances_once_per_completed_segment() -> void:
	"""ARCH-RNG-002's FORAGE draw discipline, counted on the stream itself."""
	var rng: Rng = Rng.new()
	rng.seed_world(TUTORIAL_SEED)
	var basin: Vector2i = _make_basin(2, 1000000)
	assert_equal(rng.draw_count_of(Rng.STREAM_FORAGE).value, 0, "the stream starts unspent")
	assert_true(_forage.roll_exposure_injuries(rng, basin, 0, 0, 59).ok, "59 WU is worked")
	assert_equal(rng.draw_count_of(Rng.STREAM_FORAGE).value, 0, "and rolls nothing")
	assert_true(_forage.roll_exposure_injuries(rng, basin, 0, 59, 130).ok, "on to 130 WU")
	assert_equal(rng.draw_count_of(Rng.STREAM_FORAGE).value, 2, "exactly two segments rolled")
	assert_true(_forage.roll_exposure_injuries(rng, basin, 0, 130, 600).ok, "on to 600 WU")
	assert_equal(rng.draw_count_of(Rng.STREAM_FORAGE).value, 10, "ten segments in 600 WU")


func test_natural_danger_zero_consumes_no_forage_draw() -> void:
	"""ARCH-RNG-002 rolls only "in natural danger>=1"; a stray draw would break every replay."""
	var rng: Rng = Rng.new()
	rng.seed_world(TUTORIAL_SEED)
	var safe: Vector2i = _make_basin(0, 1000000)
	var rolled: Forage.OpResult = _forage.roll_exposure_injuries(rng, safe, 0, 0, 600)
	assert_true(rolled.ok, "ten segments of safe work are fine")
	assert_equal(rolled.value, 0, "and injure nobody")
	assert_equal(rng.draw_count_of(Rng.STREAM_FORAGE).value, 0, "having drawn nothing at all")
	assert_false(_forage.roll_injury_into(rng, 0, 0, IntMath.IntResult.new()),
		"a direct roll at danger 0 refuses")
	assert_equal(rng.draw_count_of(Rng.STREAM_FORAGE).value, 0, "still without drawing")


func test_the_rolls_use_the_basins_natural_danger() -> void:
	"""ARCH-RNG-002 says natural danger; §5.5 fixes that to the basin, not the designation."""
	var rng: Rng = Rng.new()
	rng.seed_world(TUTORIAL_SEED)
	var basin: Vector2i = _make_basin(0, 1000000)
	var player_zone: Vector2i = _make_zone(ZONE_FORAGE, 3, 1000000)
	_forage.set_basin(player_zone, basin)
	assert_true(_forage.roll_exposure_injuries(rng, player_zone, 0, 0, 600).ok, "600 WU worked")
	assert_equal(rng.draw_count_of(Rng.STREAM_FORAGE).value, 0,
		"a danger 3 designation over a danger 0 basin still rolls nothing")


func test_each_roll_injures_exactly_when_the_draw_is_below_the_chance() -> void:
	"""Seed 20260905's FORAGE stream, replayed independently. Chance at danger 2, level 0 is 16."""
	var rng: Rng = Rng.new()
	rng.seed_world(TUTORIAL_SEED)
	var reference: Rng = Rng.new()
	reference.seed_world(TUTORIAL_SEED)
	var basin: Vector2i = _make_basin(2, 1000000)
	var scratch: IntMath.IntResult = IntMath.IntResult.new()
	for index: int in 40:
		var expected_draw: int = reference.draw_below(Rng.STREAM_FORAGE, 10000).value
		assert_true(_forage.roll_injury_into(rng, 2, 0, scratch), "roll %d succeeds" % index)
		assert_equal(scratch.value, 1 if expected_draw < 16 else 0,
			"roll %d agrees with draw %d against chance 16" % [index, expected_draw])


func test_the_injury_tally_over_five_thousand_segments_is_the_recorded_one() -> void:
	"""A golden count for seed 20260905: 17 of the first 5000 FORAGE draws fall below 24
	(danger 3, level 0), and 8 fall below 8 (danger 1, level 0)."""
	var rng: Rng = Rng.new()
	rng.seed_world(TUTORIAL_SEED)
	var basin: Vector2i = _make_basin(3, 1000000)
	var rolled: Forage.OpResult = _forage.roll_exposure_injuries(rng, basin, 0, 0, 300000)
	assert_true(rolled.ok, "5000 segments are rolled")
	assert_equal(rng.draw_count_of(Rng.STREAM_FORAGE).value, 5000, "one draw each")
	assert_equal(rolled.value, 17, "17 injuries at chance 24 per 10000")
	var safer: Rng = Rng.new()
	safer.seed_world(TUTORIAL_SEED)
	var mild: Vector2i = _make_basin(1, 1000000)
	assert_equal(_forage.roll_exposure_injuries(safer, mild, 0, 0, 300000).value, 8,
		"and 8 at chance 8 per 10000")


func test_the_first_injury_of_the_tutorial_seed_lands_on_its_recorded_segment() -> void:
	"""Segment ordering is observable: seed 20260905's first draw below 24 is index 237."""
	var rng: Rng = Rng.new()
	rng.seed_world(TUTORIAL_SEED)
	var basin: Vector2i = _make_basin(3, 1000000)
	var before: Forage.OpResult = _forage.roll_exposure_injuries(rng, basin, 0, 0, 237 * 60)
	assert_true(before.ok, "the first 237 segments are rolled")
	assert_equal(before.value, 0, "and none of them injures")
	var next_segment: Forage.OpResult = _forage.roll_exposure_injuries(
		rng, basin, 0, 237 * 60, 238 * 60)
	assert_true(next_segment.ok, "the 238th segment is rolled")
	assert_equal(next_segment.value, 1, "and it injures")
	assert_equal(rng.draw_count_of(Rng.STREAM_FORAGE).value, 238, "238 draws in total")


func test_an_absent_rng_is_refused_rather_than_treated_as_no_injury() -> void:
	"""A missing stream must not read as a safe outcome."""
	var basin: Vector2i = _make_basin(2, 1000000)
	var refused: Forage.OpResult = _forage.roll_exposure_injuries(null, basin, 0, 0, 60)
	assert_false(refused.ok, "a null RNG is refused")
	assert_equal(String(refused.error), "NO_RNG", "with the no-RNG code")


func test_an_unseeded_rng_refuses_without_inventing_an_outcome() -> void:
	"""rng.gd refuses every draw until seed_world() has run; that refusal must propagate."""
	var rng: Rng = Rng.new()
	var basin: Vector2i = _make_basin(2, 1000000)
	var refused: Forage.OpResult = _forage.roll_exposure_injuries(rng, basin, 0, 0, 60)
	assert_false(refused.ok, "an unseeded stream is refused")
	assert_equal(String(refused.error), "RNG_NOT_SEEDED", "with rng.gd's own code")


# --- store lifecycle ---------------------------------------------------------------------------------------------

func test_clear_returns_every_column_and_the_directory_to_empty() -> void:
	"""clear() must release directory slots as well as rows, or a private directory leaks."""
	var basin: Vector2i = _make_basin(1, 1000000)
	_forage.add_tile(basin, WEST_BASIN_TILE)
	assert_equal(_forage.zone_count(), 1, "one zone before the clear")
	_forage.clear()
	assert_equal(_forage.zone_count(), 0, "no zones after it")
	assert_equal(_forage.link_count(), 0, "no links")
	assert_equal(_forage.directory().live_count(EntityDirectory.KIND_HARVEST_ZONE), 0,
		"and no directory slot left allocated")
	assert_false(_forage.is_patch_present(0), "patch row 0 is empty")
	assert_true(_forage.create_zone(ZONE_FORAGE, 1, 1000, false, true).ok,
		"and the store designates again from empty")


func test_a_shared_directory_is_adopted_rather_than_rebuilt() -> void:
	"""resource_nodes.gd and residents.gd allocate through one directory; so does this store."""
	var shared: EntityDirectory = EntityDirectory.new()
	var store: Forage = Forage.new(shared)
	assert_true(store.create_zone(ZONE_FORAGE, 1, 1000, false, true).ok, "a zone is designated")
	assert_equal(shared.live_count(EntityDirectory.KIND_HARVEST_ZONE), 1,
		"the shared directory counts it")
	assert_equal(store.directory(), shared, "and the store hands back the same directory")


# --- decision 0030 §4.6: quota modes, compiled ids and the automatic seasonal allowance -----------

func test_the_quota_mode_ids_are_the_catalog_compilers_own_ascending_ascii_ids() -> void:
	"""Ruling §4.6: mode ids compile "through the existing catalog conventions", not a second scheme.

	Recompiled here from the same three keys the module publishes, through the same public
	compiler, so the module cannot be holding a private numbering that happens to look right.
	"""
	var compiled: Catalog.DomainResult = Catalog.compile_domain("ForageQuotaMode",
		[&"automatic", &"inherit", &"manual"] as Array[StringName])
	assert_true(compiled.ok, "the quota-mode domain compiles")
	assert_equal(compiled.ids[&"automatic"], 0, "automatic is 0")
	assert_equal(compiled.ids[&"inherit"], 1, "inherit is 1")
	assert_equal(compiled.ids[&"manual"], 2, "manual is 2")
	assert_equal(Forage.QUOTA_MODE_AUTOMATIC, 0, "and the module publishes the same three")
	assert_equal(Forage.QUOTA_MODE_INHERIT, 1, "inherit")
	assert_equal(Forage.QUOTA_MODE_MANUAL, 2, "manual")


func test_the_quota_mode_domain_is_not_a_protected_enum() -> void:
	"""§4.3 numbers no quota mode, so protecting one would give a choice a specification's standing."""
	assert_false(Catalog.PROTECTED_ENUM_DOMAINS.has("ForageQuotaMode"),
		"ForageQuotaMode is not in the protected table, like HabitatType and WeatherEvent")
	assert_equal(Catalog.fixed_enum("ForageQuotaMode"), {},
		"and the protected table hands back nothing for it")


func test_every_automatic_allowance_matches_the_hand_computed_table() -> void:
	"""R05-QTEST-11: all five patch allowances across all four seasons, as literal expectations.

	Computed by hand from §5.5's capacity, regrowth-fraction and availability columns and the
	ruling's `min(K - floor(0.8K), floor((K - floor(0.8K)) * r * S / 1000000) + 1000)`, not read
	back out of the module.
	"""
	for kind: int in EXPECTED_PATCHES_PER_ZONE:
		for season: int in 4:
			var expected: int = EXPECTED_AUTOMATIC_ALLOWANCE[kind * 4 + season]
			var actual: IntMath.IntResult = _forage.automatic_allowance_milli(kind, season)
			assert_true(actual.ok, "kind %d season %d has an allowance" % [kind, season])
			assert_equal(actual.value, expected,
				"kind %d season %d allowance is %d" % [kind, season, expected])


func test_the_automatic_daily_quota_matches_the_four_ruled_season_totals() -> void:
	"""R05-QTEST-11: spring 10720, summer 21128, autumn 22232, winter 6056 milli-U/day."""
	assert_equal(_forage.automatic_daily_quota_milli(SPRING).value, SPRING_AUTOMATIC_QUOTA,
		"spring is 10720 milli-U/day")
	assert_equal(_forage.automatic_daily_quota_milli(SUMMER).value, SUMMER_AUTOMATIC_QUOTA,
		"summer is 21128")
	assert_equal(_forage.automatic_daily_quota_milli(AUTUMN).value, AUTUMN_AUTOMATIC_QUOTA,
		"autumn is 22232")
	assert_equal(_forage.automatic_daily_quota_milli(WINTER).value, WINTER_AUTOMATIC_QUOTA,
		"winter is 6056")
	assert_false(_forage.automatic_daily_quota_milli(4).ok, "an unknown season is refused")


func test_a_created_zone_defaults_to_automatic_and_uses_the_seasonal_quota() -> void:
	"""R05-QUOTA-017: a created zone owns itself, so it is a basin, and a basin starts Automatic."""
	var made: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, 1, 999, false, true)
	var slot: int = _forage.zone_slot_of(made.ref).value
	assert_equal(_forage.quota_mode_of(slot).value, Forage.QUOTA_MODE_AUTOMATIC,
		"the default mode is Automatic")
	assert_equal(_forage.zone_quota_milli_of(slot).value, 999, "§4.2's column still stores 999")
	assert_equal(_forage.daily_quota_milli_of(slot, SUMMER).value, SUMMER_AUTOMATIC_QUOTA,
		"but the effective summer quota is the automatic one, not the stored value")
	assert_equal(_forage.daily_quota_milli_of(slot, WINTER).value, WINTER_AUTOMATIC_QUOTA,
		"and it follows the season")


func test_binding_a_zone_to_another_basin_makes_it_inherit() -> void:
	"""R05-QUOTA-018 with §4.6's Valid-use column: Automatic is a basin mode, Inherit a designation's."""
	var basin: Vector2i = _make_basin(1, 30000)
	var designation: Vector2i = _make_designation(basin)
	var slot: int = _forage.zone_slot_of(designation).value
	assert_equal(_forage.quota_mode_of(slot).value, Forage.QUOTA_MODE_INHERIT,
		"a bound zone inherits")
	assert_equal(_forage.daily_quota_milli_of(slot, SUMMER).value, 30000,
		"and its limit follows the basin's effective quota")
	assert_true(_forage.set_quota_milli(basin, 12000, SUMMER).ok, "the basin is lowered")
	assert_equal(_forage.daily_quota_milli_of(slot, SUMMER).value, 12000, "the designation follows")


func test_unbinding_a_designation_returns_it_to_automatic() -> void:
	"""Inherit is a designation mode; a zone that owns itself again cannot keep it."""
	var basin: Vector2i = _make_basin(1, 30000)
	var designation: Vector2i = _make_designation(basin)
	var slot: int = _forage.zone_slot_of(designation).value
	assert_true(_forage.set_basin(designation, designation).ok, "it becomes its own basin again")
	assert_equal(_forage.quota_mode_of(slot).value, Forage.QUOTA_MODE_AUTOMATIC,
		"and returns to Automatic")


func test_the_mode_table_refuses_a_mode_that_is_not_valid_for_the_zone() -> void:
	"""§4.6's Valid-use column is enforced, not decorative."""
	var basin: Vector2i = _make_basin(1, 30000)
	var designation: Vector2i = _make_designation(basin)
	var wrong: Forage.OpResult = _forage.set_quota_mode(basin, Forage.QUOTA_MODE_INHERIT, SUMMER)
	assert_false(wrong.ok, "a self-owned basin cannot inherit")
	assert_equal(String(wrong.error), "QUOTA_MODE_NOT_VALID_HERE", "with the mode code")
	var other: Forage.OpResult = _forage.set_quota_mode(designation,
		Forage.QUOTA_MODE_AUTOMATIC, SUMMER)
	assert_false(other.ok, "and a designation cannot be Automatic")
	assert_false(_forage.set_quota_mode(basin, 3, SUMMER).ok, "an unknown mode is refused")
	assert_equal(String(_forage.set_quota_mode(basin, -1, SUMMER).error), "INVALID_QUOTA_MODE",
		"with the invalid-mode code")


func test_a_manual_quota_is_accepted_only_between_zero_and_the_combined_capacity() -> void:
	"""R05-QUOTA-020: "only finite values from zero through the basin's combined patch capacity"."""
	var basin: Vector2i = _make_basin(1, 1000)
	assert_equal(Forage.MANUAL_QUOTA_MAX_MILLI, MANUAL_MAX,
		"the ceiling is sum(K_i) = 1180000 milli-U/day")
	assert_true(_forage.set_quota_milli(basin, 0, SUMMER).ok, "zero is the minimum, not a sentinel")
	assert_true(_forage.set_quota_milli(basin, MANUAL_MAX, SUMMER).ok, "the ceiling is inclusive")
	var over: Forage.OpResult = _forage.set_quota_milli(basin, MANUAL_MAX + 1, SUMMER)
	assert_false(over.ok, "one milli-unit above the ceiling is refused, not clamped")
	assert_equal(String(over.error), "INVALID_QUOTA", "with the invalid-quota code")
	assert_false(_forage.set_quota_milli(basin, -1, SUMMER).ok, "and a negative value is refused")
	var slot: int = _forage.zone_slot_of(basin).value
	assert_equal(_forage.zone_quota_milli_of(slot).value, MANUAL_MAX,
		"a refused write leaves the accepted value standing")


func test_a_zone_created_above_the_manual_ceiling_cannot_switch_to_manual() -> void:
	"""§4.2's column is unbounded above; R05-QUOTA-020's ceiling guards the mode that uses it."""
	var made: Forage.OpResult = _forage.create_zone(ZONE_FORAGE, 1, MANUAL_MAX + 1, false, true)
	var refused: Forage.OpResult = _forage.set_quota_mode(made.ref, Forage.QUOTA_MODE_MANUAL,
		SUMMER)
	assert_false(refused.ok, "an over-ceiling stored value cannot be made effective")
	assert_equal(String(refused.error), "INVALID_QUOTA", "with the invalid-quota code")


func test_a_manual_setting_survives_a_season_change() -> void:
	"""R05-QUOTA-019: seasons update Automatic and inherited limits, never a Manual one."""
	var manual: Vector2i = _make_basin(1, 5000)
	var automatic: Vector2i = _make_automatic_basin(1)
	var manual_slot: int = _forage.zone_slot_of(manual).value
	var automatic_slot: int = _forage.zone_slot_of(automatic).value
	assert_true(_forage.run_midnight(WINTER_MIDNIGHT_TICK, WINTER).ok, "winter opens")
	assert_equal(_forage.quota_mode_of(manual_slot).value, Forage.QUOTA_MODE_MANUAL,
		"the manual zone is still Manual")
	assert_equal(_forage.daily_quota_milli_of(manual_slot, WINTER).value, 5000,
		"and still holds the player's 5000")
	assert_equal(_forage.daily_quota_milli_of(automatic_slot, WINTER).value,
		WINTER_AUTOMATIC_QUOTA, "while the automatic basin moved to winter's 6056")


# --- decision 0030 §4.2: the daily aggregate quota ------------------------------------------------

func test_r05_qtest_01_one_daily_allowance_covers_all_five_kinds() -> void:
	"""R05-QTEST-01: berries 4000 then nuts 3000 leave 3000, not a separate 10000 for each kind."""
	var basin: Vector2i = _make_basin(1, 10000)
	var berry_zone: Vector2i = _make_designation(basin)
	var nut_zone: Vector2i = _make_designation(basin)
	assert_true(_forage.harvest(berry_zone, BERRIES, 4000, SUMMER, false).ok, "4 U of berries")
	assert_true(_forage.harvest(nut_zone, NUTS, 3000, SUMMER, false).ok, "3 U of nuts")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 7000,
		"the basin collected 7000 across both kinds")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 3000,
		"leaving 3000 of one shared daily allowance")
	assert_equal(_forage.available_quota_milli(nut_zone, SUMMER).value, 3000,
		"and the nut designation sees the berries' spend, not a fresh budget")
	assert_equal(_forage.claim_count(), 0, "no claim was involved")


func test_a_collection_through_the_basin_itself_moves_its_totals_once() -> void:
	"""Ruling §4.2: "For `z == b`, update that zone's aggregates once." The double-count guard."""
	var basin: Vector2i = _make_basin(1, 10000)
	assert_true(_forage.harvest(basin, BERRIES, 4000, SUMMER, false).ok, "4 U comes off")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 4000,
		"collected today is 4000, not 8000")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 6000, "leaving 6000")


func test_a_collection_through_a_designation_debits_both_applicable_limits() -> void:
	"""One harvest, two policy limits, one stock debit and one annual counter."""
	var basin: Vector2i = _make_basin(1, 10000)
	var designation: Vector2i = _make_designation(basin)
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_true(_forage.harvest(designation, BERRIES, 4000, SUMMER, false).ok, "4 U comes off")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 4000, "the basin counted it")
	assert_equal(_forage.harvested_today_milli_of(_slot(designation)).value, 4000,
		"and so did the designation")
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_INITIAL - 4000,
		"but only one stock was debited")
	assert_equal(_forage.harvested_year_milli_of(row).value, 4000,
		"and only one annual counter moved")


func test_r05_qtest_03_a_stricter_designation_limit_binds_below_its_basin() -> void:
	"""R05-QTEST-03: basin 10000, designation 3000 with H=1000 and R=500, gives 1500."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var designation: Vector2i = _make_designation(basin)
	assert_true(_forage.set_quota_milli(designation, 3000, SUMMER).ok, "the local limit is 3000")
	assert_true(_forage.harvest(designation, BERRIES, 1000, SUMMER, false).ok, "1 U is collected")
	var job: Vector2i = _make_job(10)
	assert_true(_forage.claim_forage(job, designation, BERRIES, 500, SUMMER, false).ok,
		"and 0.5 U is claimed")
	assert_equal(_forage.harvested_today_milli_of(_slot(designation)).value, 1000, "H is 1000")
	assert_equal(_forage.quota_reserved_milli_of(_slot(designation)).value, 500, "R is 500")
	assert_equal(_forage.available_quota_milli(designation, SUMMER).value, 1500,
		"so 3000 - 1000 - 500 binds below the basin's 8500")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 8500,
		"while the basin itself still has 8500")


func test_a_designation_with_a_larger_manual_limit_cannot_widen_its_basin() -> void:
	"""§4.6: "A designation's larger manual setting cannot expand its basin's allowance"."""
	var basin: Vector2i = _make_basin(1, 4000)
	var designation: Vector2i = _make_designation(basin)
	assert_true(_forage.set_quota_milli(designation, MANUAL_MAX, SUMMER).ok, "it asks for the lot")
	assert_equal(_forage.available_quota_milli(designation, SUMMER).value, 4000,
		"the basin's 4000 still binds")
	var over: Forage.OpResult = _forage.harvest(designation, BERRIES, 4001, SUMMER, false)
	assert_false(over.ok, "and 4001 is refused")
	assert_equal(String(over.error), "QUOTA_REACHED", "with the quota code")


func test_the_available_quota_reader_never_reports_a_negative_allowance() -> void:
	"""`max(0, ...)`: a limit lowered below what is already spent reports zero, never a deficit."""
	var basin: Vector2i = _make_basin(1, 10000)
	assert_true(_forage.harvest(basin, BERRIES, 8000, SUMMER, false).ok, "8 U is collected")
	assert_true(_forage.set_quota_milli(basin, 3000, SUMMER).ok, "the limit drops below that")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 0, "availability is zero")
	assert_true(_forage.is_quota_reached(basin, SUMMER), "and the quota reads as reached")


# --- decision 0030 §4.3: claims ------------------------------------------------------------------

func test_a_store_without_a_job_store_refuses_every_claim_operation() -> void:
	"""Claims are owned by Jobs; a store with no Job store refuses rather than inventing an owner."""
	var basin: Vector2i = _make_basin(1, 10000)
	assert_null(_forage.jobs(), "this store has no Job store")
	var refused: Forage.OpResult = _forage.claim_forage(NULL_REF, basin, BERRIES, 100, SUMMER,
		false)
	assert_false(refused.ok, "claiming is refused")
	assert_equal(String(refused.error), "NO_JOB_STORE", "with the no-job-store code")
	assert_equal(String(_forage.release_claim(NULL_REF).error), "NO_JOB_STORE", "so is releasing")
	assert_equal(String(_forage.collect_claim(NULL_REF, 1, SUMMER, false).error), "NO_JOB_STORE",
		"so is collecting")
	assert_equal(String(_forage.rebuild_reservation_aggregates().error), "NO_JOB_STORE",
		"and so is rebuilding")


func test_a_claim_reserves_the_complete_intended_collection_on_both_limits() -> void:
	"""R05-QUOTA-006: an outstanding claim counts in both applicable quota reservation totals."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var designation: Vector2i = _make_designation(basin)
	var job: Vector2i = _make_job(10)
	var claimed: Forage.OpResult = _forage.claim_forage(job, designation, BERRIES, 6000, SUMMER,
		false)
	assert_true(claimed.ok, "the claim is accepted (error: %s)" % claimed.error)
	assert_equal(_forage.claim_count(), 1, "one claim is active")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 6000, "the basin reserved it")
	assert_equal(_forage.quota_reserved_milli_of(_slot(designation)).value, 6000,
		"and so did the designation")
	assert_equal(_forage.stock_reserved_milli(basin, BERRIES).value, 6000,
		"the basin's berry stock is spoken for")
	assert_equal(_forage.stock_reserved_milli(basin, NUTS).value, 0, "its nuts are not")
	assert_equal(_forage.claim_remaining_milli_of(claimed.value).value, 6000, "nothing collected")


func test_a_claim_on_the_basin_itself_reserves_once() -> void:
	"""The `z == b` rule applies to reservation exactly as it applies to collection."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var job: Vector2i = _make_job(10)
	assert_true(_forage.claim_forage(job, basin, BERRIES, 6000, SUMMER, false).ok, "6 U is claimed")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 6000, "reserved once")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 4000, "leaving 4000")


func test_r05_qtest_02_a_second_designation_cannot_reserve_past_the_shared_allowance() -> void:
	"""R05-QTEST-02: the second complete reservation is refused atomically; 4000 remains."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var first: Vector2i = _make_designation(basin)
	var second: Vector2i = _make_designation(basin)
	assert_true(_forage.claim_forage(_make_job(10), first, BERRIES, 6000, SUMMER, false).ok,
		"the first designation reserves 6 U")
	var late_job: Vector2i = _make_job(20)
	var refused: Forage.OpResult = _forage.claim_forage(late_job, second, BERRIES, 5000, SUMMER,
		false)
	assert_false(refused.ok, "the second cannot reserve 5 U")
	assert_equal(String(refused.error), "QUOTA_REACHED", "with the quota code")
	assert_equal(_forage.claim_count(), 1, "and no partial claim was written")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 6000, "R is unchanged")
	assert_equal(_forage.quota_reserved_milli_of(_slot(second)).value, 0,
		"the refused designation reserved nothing")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 4000, "4000 remains")
	assert_true(_forage.claim_forage(late_job, second, BERRIES, 4000, SUMMER, false).ok,
		"and exactly 4000 does fit")


func test_one_job_owns_at_most_one_claim_and_a_member_owns_none() -> void:
	"""§4.3: one pending claim per owning Job; shared work claims through its COORDINATOR."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 100000)
	var coordinator: Vector2i = _make_job(10)
	var member: Vector2i = _make_job(20, 0)
	assert_true(_jobs.make_coordinator(_job_slot(coordinator)).ok, "one job coordinates")
	assert_true(_jobs.set_coordinator(_job_slot(member), _job_slot(coordinator)).ok,
		"the other joins its party")
	var refused: Forage.OpResult = _forage.claim_forage(member, basin, BERRIES, 1000, SUMMER,
		false)
	assert_false(refused.ok, "a member cannot hold a claim of its own")
	assert_equal(String(refused.error), "JOB_IS_MEMBER", "with the member code")
	assert_true(_forage.claim_forage(coordinator, basin, BERRIES, 1000, SUMMER, false).ok,
		"the coordinator can")
	var again: Forage.OpResult = _forage.claim_forage(coordinator, basin, NUTS, 1000, SUMMER,
		false)
	assert_false(again.ok, "a second kind needs a second job")
	assert_equal(String(again.error), "CLAIM_ALREADY_PRESENT", "with the already-present code")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 1000, "one reservation only")


func test_r05_qtest_07_a_partial_collection_keeps_only_the_uncollected_quantity() -> void:
	"""R05-QTEST-07: claim 6000, collect 2000; R and the claim fall to 4000 and one cargo is due."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var designation: Vector2i = _make_designation(basin)
	var job: Vector2i = _make_job(10)
	var row: int = _forage.claim_forage(job, designation, BERRIES, 6000, SUMMER, false).value
	var patch: int = _forage.patch_row_for_zone(basin, BERRIES).value
	var collected: Forage.OpResult = _forage.collect_claim(job, 2000, SUMMER, false)
	assert_true(collected.ok, "2 U is collected (error: %s)" % collected.error)
	assert_equal(collected.value, 2000, "and exactly 2000 is reported, for one cargo creation")
	assert_equal(_forage.claim_remaining_milli_of(row).value, 4000, "4000 is still promised")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 4000, "the basin's R fell")
	assert_equal(_forage.quota_reserved_milli_of(_slot(designation)).value, 4000, "so did its own")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 2000, "the basin's H rose")
	assert_equal(_forage.harvested_today_milli_of(_slot(designation)).value, 2000, "so did its own")
	assert_equal(_forage.harvested_year_milli_of(patch).value, 2000, "the annual counter rose once")
	assert_equal(_forage.stock_milli_of(patch).value, BERRIES_INITIAL - 2000, "stock fell once")


func test_collecting_the_whole_claim_closes_it() -> void:
	"""A claim collected to zero closes: its Job must reacquire before collecting again."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var job: Vector2i = _make_job(10)
	var row: int = _forage.claim_forage(job, basin, BERRIES, 3000, SUMMER, false).value
	assert_true(_forage.collect_claim(job, 3000, SUMMER, false).ok, "the whole claim is collected")
	assert_false(_forage.is_claim_active(row), "the claim row is empty")
	assert_equal(_forage.claim_count(), 0, "and the live count fell")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 0, "nothing stays reserved")
	var again: Forage.OpResult = _forage.collect_claim(job, 1, SUMMER, false)
	assert_false(again.ok, "a closed claim collects nothing further")
	assert_equal(String(again.error), "CLAIM_NOT_PRESENT", "with the not-present code")


func test_a_collection_larger_than_the_claim_is_refused_not_clamped() -> void:
	"""A silent over-collection would let a job book cargo the claim never promised."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var job: Vector2i = _make_job(10)
	var row: int = _forage.claim_forage(job, basin, BERRIES, 3000, SUMMER, false).value
	var over: Forage.OpResult = _forage.collect_claim(job, 3001, SUMMER, false)
	assert_false(over.ok, "3001 against a 3000 claim is refused")
	assert_equal(String(over.error), "INVALID_AMOUNT", "with the invalid-amount code")
	assert_false(_forage.collect_claim(job, 0, SUMMER, false).ok, "zero is refused")
	assert_equal(_forage.claim_remaining_milli_of(row).value, 3000, "and the claim is untouched")


func test_a_claim_does_not_bypass_collection_time_validation() -> void:
	"""§4.3: "A claim does not bypass collection-time validation"."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var job: Vector2i = _make_job(10)
	assert_true(_forage.claim_forage(job, basin, BERRIES, 3000, SUMMER, false).ok, "3 U is claimed")
	_forage.set_zone_protected(basin, true)
	assert_equal(String(_forage.collect_claim(job, 1000, SUMMER, false).error), "ZONE_PROTECTED",
		"a protected zone still refuses")
	_forage.set_zone_protected(basin, false)
	_forage.set_zone_enabled(basin, false)
	assert_equal(String(_forage.collect_claim(job, 1000, SUMMER, false).error), "ZONE_DISABLED",
		"and so does a disabled one")
	_forage.set_zone_enabled(basin, true)
	assert_equal(String(_forage.collect_claim(job, 1000, WINTER, false).error), "PATCH_DORMANT",
		"and a dormant season refuses too")
	assert_true(_forage.collect_claim(job, 1000, SUMMER, false).ok, "the valid case still passes")


func test_releasing_a_claim_returns_its_allowance_and_produces_nothing_else() -> void:
	"""§4.5: "Releasing a claim does not itself generate productive WU, XP, cargo or a refund"."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var job: Vector2i = _make_job(10)
	var patch: int = _forage.patch_row_for_zone(basin, BERRIES).value
	var row: int = _forage.claim_forage(job, basin, BERRIES, 3000, SUMMER, false).value
	var mwu_before: int = _jobs.remaining_mwu_of(_job_slot(job)).value
	assert_true(_forage.release_claim(job).ok, "the claim releases")
	assert_false(_forage.is_claim_active(row), "its row is empty")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 0, "R returns to zero")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 0, "H did not move")
	assert_equal(_forage.stock_milli_of(patch).value, BERRIES_INITIAL, "no stock was returned")
	assert_equal(_forage.harvested_year_milli_of(patch).value, 0, "no annual counter moved")
	assert_equal(_jobs.remaining_mwu_of(_job_slot(job)).value, mwu_before, "and no work was booked")


func test_r05_qtest_08_a_worker_change_keeps_the_owning_jobs_claim_and_cancellation_ends_it() -> void:
	"""R05-QTEST-08: replacement preserves the claim; cancellation releases only what is uncollected."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var coordinator: Vector2i = _make_job(10)
	var member: Vector2i = _make_job(20, 0)
	assert_true(_jobs.make_coordinator(_job_slot(coordinator)).ok, "the party has a coordinator")
	assert_true(_jobs.set_coordinator(_job_slot(member), _job_slot(coordinator)).ok, "and a member")
	var row: int = _forage.claim_forage(coordinator, basin, BERRIES, 5000, SUMMER, false).value
	assert_true(_forage.collect_claim(coordinator, 2000, SUMMER, false).ok, "2 U is collected")
	var first_worker: int = _spawn_worker()
	assert_true(_jobs.assign_worker(first_worker, _job_slot(member)).ok, "a worker takes the member")
	assert_true(_jobs.release_worker(first_worker).ok, "and then leaves")
	assert_true(_jobs.assign_worker(_spawn_worker(), _job_slot(member)).ok, "another replaces them")
	assert_equal(_forage.claim_remaining_milli_of(row).value, 3000,
		"the coordinator's claim is untouched by the replacement")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 3000, "and so is R")
	assert_true(_jobs.set_state(_job_slot(coordinator), CANCELLED_STATE).ok, "the job is cancelled")
	assert_equal(_forage.release_cancelled_claims().value, 1, "its claim is released")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 0, "R returns to zero")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 2000,
		"and the 2 U already collected is retained")


func test_r05_qtest_13_a_reused_job_row_cannot_act_under_the_previous_generation_claim() -> void:
	"""R05-QTEST-13 / R05-QUOTA-023: the stored Job reference AND generation are validated."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var first: Vector2i = _make_job(10)
	var row: int = _forage.claim_forage(first, basin, BERRIES, 3000, SUMMER, false).value
	assert_true(_jobs.destroy_job(_job_slot(first)).ok, "the owning job is retired")
	var second: Vector2i = _make_job(20)
	assert_equal(_job_slot(second), row, "the replacement job reuses that very row")
	assert_equal(String(_forage.collect_claim(second, 1000, SUMMER, false).error),
		"CLAIM_STALE_JOB", "the newcomer cannot collect under the old claim")
	assert_equal(String(_forage.release_claim(second).error), "CLAIM_STALE_JOB",
		"nor release it")
	assert_equal(String(_forage.claim_forage(second, basin, NUTS, 100, SUMMER, false).error),
		"CLAIM_STALE_JOB", "nor claim over it")
	assert_equal(_forage.purge_stale_claims().value, 1, "purging is the explicit way out")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 0, "R is returned")
	assert_true(_forage.claim_forage(second, basin, NUTS, 100, SUMMER, false).ok,
		"and the row is claimable again")


func test_r05_qtest_15_a_failed_preflight_leaves_every_quantity_unchanged() -> void:
	"""R05-QTEST-15: quota, floor and reservation preflights each refuse without partial effect.

	The OUTPUT-CAPACITY leg of this fixture is not exercised: container capacity and the Job-owned
	output reservation live in inventory.gd and jobs.gd, and no binding between a Job and a
	reserved container exists yet (module header).
	"""
	_use_job_store()
	var tight: Vector2i = _make_basin(1, 10000)
	var patch: int = _forage.patch_row_for_zone(tight, BERRIES).value
	var over_quota: Forage.OpResult = _forage.claim_forage(_make_job(10), tight, BERRIES, 10001,
		SUMMER, false)
	assert_equal(String(over_quota.error), "QUOTA_REACHED", "the quota leg refuses")
	_assert_nothing_reserved(tight, patch)
	var rich: Vector2i = _make_basin(1, MANUAL_MAX)
	var rich_patch: int = _forage.patch_row_for_zone(rich, BERRIES).value
	var over_floor: Forage.OpResult = _forage.claim_forage(_make_job(20), rich, BERRIES, 180001,
		SUMMER, false)
	assert_equal(String(over_floor.error), "BELOW_HARVEST_FLOOR", "the floor leg refuses")
	_assert_nothing_reserved(rich, rich_patch)
	assert_true(_forage.claim_forage(_make_job(30), rich, BERRIES, 180000, SUMMER, false).ok,
		"the whole harvestable stock is claimed")
	var over_reserved: Forage.OpResult = _forage.claim_forage(_make_job(40), rich, BERRIES, 1,
		SUMMER, false)
	assert_equal(String(over_reserved.error), "STOCK_RESERVED", "the reservation leg refuses")
	assert_equal(_forage.quota_reserved_milli_of(_slot(rich)).value, 180000, "R is unchanged")
	assert_equal(_forage.stock_milli_of(rich_patch).value, BERRIES_INITIAL, "stock is unchanged")


func _assert_nothing_reserved(zone: Vector2i, patch_row: int) -> void:
	"""No claim, no reservation, no collected total and no stock movement survived a refusal."""
	assert_equal(_forage.claim_count(), 0, "no claim exists")
	assert_equal(_forage.quota_reserved_milli_of(_slot(zone)).value, 0, "nothing is reserved")
	assert_equal(_forage.harvested_today_milli_of(_slot(zone)).value, 0, "nothing was collected")
	assert_equal(_forage.stock_milli_of(patch_row).value, BERRIES_INITIAL, "stock is untouched")


func test_an_unclaimed_harvest_cannot_take_stock_another_claim_promised() -> void:
	"""`stock_available = max(0, stock - floor - stock_reserved)` binds the unclaimed path too."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, MANUAL_MAX)
	assert_true(_forage.claim_forage(_make_job(10), basin, BERRIES, 179000, SUMMER, false).ok,
		"179 U is claimed")
	assert_equal(_forage.stock_available_milli(basin, BERRIES, false).value, 1000,
		"1 U is left unclaimed above the floor")
	assert_equal(_forage.harvestable_milli(basin, BERRIES, SUMMER, false).value, 1000,
		"and that is what harvestable reports")
	var refused: Forage.OpResult = _forage.harvest(basin, BERRIES, 1001, SUMMER, false)
	assert_false(refused.ok, "1001 is refused")
	assert_equal(String(refused.error), "STOCK_RESERVED", "with the reserved code")
	assert_true(_forage.harvest(basin, BERRIES, 1000, SUMMER, false).ok, "1000 exactly fits")


# --- decision 0030 §4.5: reconciliation ------------------------------------------------------------

func test_r05_qtest_05_a_quota_cut_releases_whole_claims_newest_first() -> void:
	"""R05-QTEST-05: H=2000 with claims 3000 and 4000; cutting to 6000 releases the newest whole."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	assert_true(_forage.harvest(basin, BERRIES, 2000, SUMMER, false).ok, "2 U is collected")
	var older: Vector2i = _make_job(100)
	var newer: Vector2i = _make_job(200)
	var older_row: int = _forage.claim_forage(older, basin, BERRIES, 3000, SUMMER, false).value
	var newer_row: int = _forage.claim_forage(newer, basin, BERRIES, 4000, SUMMER, false).value
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 7000, "7000 is outstanding")
	assert_equal(_forage.claims_released_by_quota(basin, 6000, SUMMER).value, 1,
		"the preview reader says one job is affected")
	var cut: Forage.OpResult = _forage.set_quota_milli(basin, 6000, SUMMER)
	assert_true(cut.ok, "the cut applies")
	assert_equal(cut.value, 1, "and releases exactly one claim")
	assert_false(_forage.is_claim_active(newer_row), "the newest claim went")
	assert_true(_forage.is_claim_active(older_row), "the oldest stayed")
	assert_equal(_forage.claim_remaining_milli_of(older_row).value, 3000,
		"whole, not shrunk to fit")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 3000, "R is 3000")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 1000, "and 1000 is available")


func test_the_release_order_breaks_a_created_tick_tie_by_persistent_id() -> void:
	"""§4.5 orders by `(job.created_tick, job.persistent_id)` descending, so the tiebreak matters."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var first: Vector2i = _make_job(100)
	var second: Vector2i = _make_job(100)
	var first_row: int = _forage.claim_forage(first, basin, BERRIES, 3000, SUMMER, false).value
	var second_row: int = _forage.claim_forage(second, basin, BERRIES, 3000, SUMMER, false).value
	assert_true(_forage.claim_persistent_id_of(second_row).value
		> _forage.claim_persistent_id_of(first_row).value,
		"the later job carries the higher persistent id")
	assert_equal(_forage.claim_created_tick_of(first_row).value,
		_forage.claim_created_tick_of(second_row).value, "and both were created on the same tick")
	assert_equal(_forage.set_quota_milli(basin, 3000, SUMMER).value, 1, "one claim is released")
	assert_true(_forage.is_claim_active(first_row), "the lower persistent id survives")
	assert_false(_forage.is_claim_active(second_row), "the higher one goes first")


func test_r05_qtest_06_a_cut_below_todays_collected_total_releases_everything() -> void:
	"""R05-QTEST-06: H stays, every affected claim goes, availability is zero, cargo persists."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var patch: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_true(_forage.harvest(basin, BERRIES, 5000, SUMMER, false).ok, "5 U is collected")
	var job: Vector2i = _make_job(10)
	assert_true(_forage.claim_forage(job, basin, BERRIES, 1000, SUMMER, false).ok, "1 U is claimed")
	assert_equal(_forage.set_quota_milli(basin, 2000, SUMMER).value, 1, "the cut releases it")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 5000, "H is still 5000")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 0, "R is zero")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 0, "availability is zero")
	assert_equal(_forage.harvested_year_milli_of(patch).value, 5000, "history is not undone")
	assert_equal(_forage.stock_milli_of(patch).value, BERRIES_INITIAL - 5000,
		"and the collected stock is not returned")


func test_a_zero_quota_releases_every_claim_that_limit_reaches() -> void:
	"""§4.6: "Minimum is zero: no new harvesting, with existing claims reconciled by §4.5"."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var designation: Vector2i = _make_designation(basin)
	assert_true(_forage.claim_forage(_make_job(10), designation, BERRIES, 2000, SUMMER, false).ok,
		"a designation claim exists")
	assert_true(_forage.claim_forage(_make_job(20), basin, NUTS, 2000, SUMMER, false).ok,
		"and a basin claim")
	assert_equal(_forage.set_quota_milli(designation, 0, SUMMER).value, 1,
		"zeroing the designation releases only the claim that limit reaches")
	assert_equal(_forage.claim_count(), 1, "the basin's own claim survives")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 2000, "carrying 2000 of R")
	assert_equal(_forage.set_quota_milli(basin, 0, SUMMER).value, 1, "zeroing the basin takes it")
	assert_equal(_forage.claim_count(), 0, "no claim survives a zero basin limit")


func test_a_claim_released_by_reconciliation_must_be_reacquired_before_collecting() -> void:
	"""R05-QUOTA-014: a released claim collects nothing until its Job reacquires."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var job: Vector2i = _make_job(10)
	assert_true(_forage.claim_forage(job, basin, BERRIES, 4000, SUMMER, false).ok, "4 U is claimed")
	assert_equal(_forage.set_quota_milli(basin, 0, SUMMER).value, 1, "the limit releases it")
	var refused: Forage.OpResult = _forage.collect_claim(job, 1000, SUMMER, false)
	assert_false(refused.ok, "collection is refused")
	assert_equal(String(refused.error), "CLAIM_NOT_PRESENT", "with the not-present code")
	assert_true(_forage.set_quota_milli(basin, 10000, SUMMER).ok, "the limit is restored")
	assert_true(_forage.claim_forage(job, basin, BERRIES, 4000, SUMMER, false).ok,
		"and the job reacquires before it can collect")
	assert_true(_forage.collect_claim(job, 1000, SUMMER, false).ok, "then collection works")


func test_reconciliation_considers_both_applicable_limits() -> void:
	"""§4.5: "release a claim when its applicable basin OR designation remains over its total"."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, MANUAL_MAX)
	var designation: Vector2i = _make_designation(basin)
	assert_true(_forage.set_quota_milli(designation, 8000, SUMMER).ok, "the local limit is 8000")
	assert_true(_forage.claim_forage(_make_job(10), designation, BERRIES, 8000, SUMMER, false).ok,
		"the designation reserves all 8 U of its own limit")
	assert_equal(_forage.set_quota_milli(designation, 4000, SUMMER).value, 1,
		"halving the DESIGNATION limit releases the claim, though the basin is untroubled")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 0,
		"and the basin's own outstanding total came back down with it")


func test_the_affected_job_reader_counts_without_changing_anything() -> void:
	"""R05-QUOTA-015's number. The preview panel that would show it is the UI's, not this store's."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 12000)
	_forage.claim_forage(_make_job(100), basin, BERRIES, 3000, SUMMER, false)
	_forage.claim_forage(_make_job(200), basin, BERRIES, 3000, SUMMER, false)
	_forage.claim_forage(_make_job(300), basin, BERRIES, 3000, SUMMER, false)
	assert_equal(_forage.claims_released_by_quota(basin, 12000, SUMMER).value, 0,
		"no cut, no affected jobs")
	assert_equal(_forage.claims_released_by_quota(basin, 9000, SUMMER).value, 0,
		"a limit that exactly equals the outstanding total affects none either")
	assert_equal(_forage.claims_released_by_quota(basin, 8000, SUMMER).value, 1,
		"9000 outstanding against 8000 affects one job")
	assert_equal(_forage.claims_released_by_quota(basin, 2000, SUMMER).value, 3,
		"and a 2000 limit affects all three")
	assert_equal(_forage.claim_count(), 3, "the reader changed nothing")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 9000, "R is untouched")


func test_deleting_or_rebinding_a_designation_releases_its_claims_first() -> void:
	"""R05-QUOTA-016, and "neither deletion nor rebinding resets basin usage"."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var other: Vector2i = _make_basin(1, 20000)
	var designation: Vector2i = _make_designation(basin)
	assert_true(_forage.harvest(designation, BERRIES, 4000, SUMMER, false).ok, "4 U is collected")
	assert_true(_forage.claim_forage(_make_job(10), designation, BERRIES, 3000, SUMMER, false).ok,
		"and 3 U is claimed")
	assert_true(_forage.set_basin(designation, other).ok, "the designation is rebound")
	assert_equal(_forage.claim_count(), 0, "its claim went first")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 0, "the old basin's R cleared")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 4000,
		"but its collected total is not reset")
	assert_true(_forage.claim_forage(_make_job(20), designation, BERRIES, 3000, SUMMER, false).ok,
		"a fresh claim against the new basin is accepted")
	assert_true(_forage.destroy_zone(designation).ok, "and deleting it releases that one too")
	assert_equal(_forage.claim_count(), 0, "no claim outlives its designation")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 4000,
		"with the basin's usage still standing")


func test_r05_qtest_09_deleting_and_redrawing_a_designation_creates_no_stock_or_allowance() -> void:
	"""R05-QTEST-09: basin H and the annual counter persist; the new designation gains nothing."""
	var basin: Vector2i = _make_basin(1, 10000)
	var first: Vector2i = _make_designation(basin)
	var patch: int = _forage.patch_row_for_zone(basin, BERRIES).value
	assert_true(_forage.harvest(first, BERRIES, 4000, SUMMER, false).ok, "4 U is collected")
	assert_true(_forage.destroy_zone(first).ok, "the designation is deleted")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 4000, "basin H persists")
	assert_equal(_forage.harvested_year_milli_of(patch).value, 4000, "the annual counter persists")
	var second: Vector2i = _make_designation(basin)
	assert_equal(_forage.available_quota_milli(second, SUMMER).value, 6000,
		"the redrawn designation inherits the spend, not a fresh allowance")
	assert_equal(_forage.patch_count_of(_slot(second)).value, 0, "it owns no patches")
	var conjured: Forage.OpResult = _forage.create_patch(second, BERRIES, 10)
	assert_false(conjured.ok, "and it cannot conjure a stock of its own")
	assert_equal(String(conjured.error), "ZONE_IS_BOUND", "with the bound code")


# --- decision 0030 §4.4: midnight -----------------------------------------------------------------

func test_midnight_is_an_offset_calendar_crossing_and_not_a_tick_multiple() -> void:
	"""§4.4: "Do not reset on `tick % 18000 == 0`: tick zero begins at 06:00"."""
	var basin: Vector2i = _make_basin(1, 10000)
	assert_true(_forage.harvest(basin, BERRIES, 4000, SUMMER, false).ok, "4 U is collected")
	var not_midnight: Forage.OpResult = _forage.run_midnight(TICKS_PER_DAY, SUMMER)
	assert_false(not_midnight.ok, "tick 18000 is 06:00 of day 2, not a boundary")
	assert_equal(String(not_midnight.error), "NOT_DAY_BOUNDARY", "with the boundary code")
	assert_false(_forage.run_midnight(0, SUMMER).ok, "tick 0 starts no new day either")
	assert_false(_forage.run_midnight(-1, SUMMER).ok, "and a negative tick is refused")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 4000,
		"none of those refusals reset anything")
	assert_true(_forage.run_midnight(FIRST_MIDNIGHT_TICK, SUMMER).ok, "tick 13500 is the first")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 0, "and it resets H")


func test_r05_qtest_04_claims_survive_midnight_and_consume_the_new_days_allowance() -> void:
	"""R05-QTEST-04: H=4000 R=3000 becomes H=0 R=3000 with 7000 available; collecting 2000 holds it."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var job: Vector2i = _make_job(10)
	assert_true(_forage.harvest(basin, BERRIES, 4000, SUMMER, false).ok, "4 U is collected")
	var row: int = _forage.claim_forage(job, basin, BERRIES, 3000, SUMMER, false).value
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 3000, "3000 is left today")
	assert_equal(_forage.run_midnight(SUMMER_MIDNIGHT_TICK, SUMMER).value, 0, "nothing is released")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 0, "H resets to zero")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 3000, "R is preserved")
	assert_true(_forage.is_claim_active(row), "and so is the claim itself")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 7000,
		"the outstanding claim consumes part of the new day's allowance")
	assert_true(_forage.collect_claim(job, 2000, SUMMER, false).ok, "2 U is collected")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 2000, "H is 2000")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 1000, "R is 1000")
	assert_equal(_forage.available_quota_milli(basin, SUMMER).value, 7000,
		"and availability is unchanged, because reserved became collected")


func test_midnight_does_not_reset_the_annual_counter_or_renew_a_lease() -> void:
	"""R05-QUOTA-011 and §4.4's "Annual patch counters reset only at the year boundary"."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var patch: int = _forage.patch_row_for_zone(basin, BERRIES).value
	var job: Vector2i = _make_job(10)
	assert_true(_forage.harvest(basin, BERRIES, 4000, SUMMER, false).ok, "4 U is collected")
	assert_true(_forage.claim_forage(job, basin, BERRIES, 1000, SUMMER, false).ok, "1 U is claimed")
	var worker: int = _spawn_worker()
	assert_true(_jobs.assign_worker(worker, _job_slot(job)).ok, "a worker holds the job")
	assert_equal(_jobs.lease_expiry_of(worker).value, 0, "its lease starts at 0, unimplemented")
	assert_true(_forage.run_midnight(SUMMER_MIDNIGHT_TICK, SUMMER).ok, "midnight runs")
	assert_equal(_forage.harvested_year_milli_of(patch).value, 4000, "the annual counter stands")
	assert_equal(_jobs.lease_expiry_of(worker).value, 0,
		"and no lease was renewed or extended by the crossing")
	assert_equal(_jobs.created_tick_of(_job_slot(job)).value, 10, "the job's own tick is untouched")


func test_r05_qtest_10_a_boundary_releases_closed_and_excess_claims_deterministically() -> void:
	"""R05-QTEST-10: a kind that closes for the season goes; valid claims stay; nothing collects between."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, MANUAL_MAX)
	var berry_job: Vector2i = _make_job(10)
	var root_job: Vector2i = _make_job(20)
	var berry_row: int = _forage.claim_forage(berry_job, basin, BERRIES, 2000, SUMMER, false).value
	var root_row: int = _forage.claim_forage(root_job, basin, ROOTS, 2000, SUMMER, false).value
	assert_equal(_forage.run_midnight(WINTER_MIDNIGHT_TICK, WINTER).value, 1,
		"winter closes berries, so exactly that claim is released")
	assert_false(_forage.is_claim_active(berry_row), "the dormant kind's claim went")
	assert_true(_forage.is_claim_active(root_row), "the still-available kind's claim stayed")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 2000, "R holds only the roots")
	assert_equal(String(_forage.collect_claim(berry_job, 1, WINTER, false).error),
		"CLAIM_NOT_PRESENT", "and the released claim admits no collection afterwards")


func test_a_lower_automatic_quota_at_a_boundary_releases_the_excess_claim() -> void:
	"""R05-QTEST-10's other half: autumn 22232 falls to winter 6056 and the excess must go."""
	_use_job_store()
	var basin: Vector2i = _make_automatic_basin(1)
	var fits: Vector2i = _make_job(10)
	var fits_row: int = _forage.claim_forage(fits, basin, ROOTS, 6000, AUTUMN, false).value
	assert_equal(_forage.run_midnight(WINTER_MIDNIGHT_TICK, WINTER).value, 0,
		"6000 still fits winter's 6056")
	assert_true(_forage.is_claim_active(fits_row), "so that claim survives")
	assert_true(_forage.release_claim(fits).ok, "clear it and try one that does not fit")
	var over: Vector2i = _make_job(20)
	var over_row: int = _forage.claim_forage(over, basin, ROOTS, 6100, AUTUMN, false).value
	assert_equal(_forage.run_midnight(WINTER_MIDNIGHT_TICK, WINTER).value, 1,
		"6100 exceeds winter's 6056, so the whole claim is released")
	assert_false(_forage.is_claim_active(over_row), "nothing is shrunk to fit")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 0, "and R returns to zero")


func test_midnight_refuses_an_unknown_season_without_resetting_anything() -> void:
	"""A refusal at the boundary must not half-apply the ruled order."""
	var basin: Vector2i = _make_basin(1, 10000)
	assert_true(_forage.harvest(basin, BERRIES, 4000, SUMMER, false).ok, "4 U is collected")
	var refused: Forage.OpResult = _forage.run_midnight(FIRST_MIDNIGHT_TICK, 4)
	assert_false(refused.ok, "an unknown season is refused")
	assert_equal(String(refused.error), "INVALID_SEASON", "with the season code")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 4000, "and H is untouched")


# --- decision 0030 §4.7: the load path, its aggregates and the packed payload ----------------------

func test_r05_qtest_12_restored_claims_rebuild_the_reservation_aggregates() -> void:
	"""R05-QTEST-12's in-process substance: authoritative records restore, derived totals rebuild.

	BLOCKED: the fixture's cross-process save/load round trip cannot be run, because this
	repository has no save module at all. What is exercised here is the load path itself --
	restore_claim() writes the authoritative record without maintaining the derived cache, and
	rebuild_reservation_aggregates() reconstructs every outstanding total from the claim table.
	"""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var designation: Vector2i = _make_designation(basin)
	assert_true(_forage.harvest(designation, BERRIES, 2000, SUMMER, false).ok, "2 U was collected")
	var job: Vector2i = _make_job(10)
	var row: int = _forage.restore_claim(job, designation, BERRIES, 3000).value
	assert_true(_forage.is_claim_active(row), "the saved claim record is restored")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 0,
		"and the derived total is still empty, exactly as a loader leaves it")
	assert_equal(_forage.rebuild_reservation_aggregates().value, 1, "one claim is counted")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 3000, "the basin's R rebuilds")
	assert_equal(_forage.quota_reserved_milli_of(_slot(designation)).value, 3000, "and its own")
	assert_equal(_forage.harvested_today_milli_of(_slot(basin)).value, 2000,
		"no synthetic daily reset happened")
	assert_true(_forage.collect_claim(job, 3000, SUMMER, false).ok,
		"and the restored claim collects normally afterwards")


func test_the_rebuild_counts_a_claim_once_when_its_two_references_are_identical() -> void:
	"""§4.7: "counting a claim once when those references are identical"."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var job: Vector2i = _make_job(10)
	assert_true(_forage.restore_claim(job, basin, BERRIES, 3000).ok, "a basin-owned claim restores")
	assert_equal(_forage.rebuild_reservation_aggregates().value, 1, "one claim is counted")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 3000,
		"the basin reserved 3000, not 6000")


func test_the_rebuild_discards_a_stale_cached_total_instead_of_adding_to_it() -> void:
	"""Every zone total is zeroed before the claim table is summed, so drift cannot survive."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var job: Vector2i = _make_job(10)
	assert_true(_forage.claim_forage(job, basin, BERRIES, 3000, SUMMER, false).ok, "3 U is claimed")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 3000, "R is maintained live")
	assert_equal(_forage.rebuild_reservation_aggregates().value, 1, "rebuilding counts it once")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 3000,
		"and rebuilding an already-correct total does not double it")


func test_restore_claim_validates_its_references_kind_and_quantity() -> void:
	"""§4.7's load validation: references, positive quantities, patch kinds and owner indexing."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 20000)
	var job: Vector2i = _make_job(10)
	assert_equal(String(_forage.restore_claim(job, basin, BERRIES, 0).error), "INVALID_AMOUNT",
		"a zero quantity is refused")
	assert_equal(String(_forage.restore_claim(job, basin, BERRIES, MANUAL_MAX + 1).error),
		"INVALID_AMOUNT", "so is one above the policy ceiling")
	assert_equal(String(_forage.restore_claim(job, basin, 5, 1000).error), "INVALID_PATCH_KIND",
		"an unknown kind is refused")
	assert_equal(String(_forage.restore_claim(NULL_REF, basin, BERRIES, 1000).error),
		"JOB_NOT_PRESENT", "and so is a job reference that names nothing")
	assert_equal(_forage.claim_count(), 0, "no refusal wrote a row")


func test_r05_qtest_16_the_packed_payload_matches_the_ruled_allocation() -> void:
	"""R05-QTEST-16: sizes derived from the actual fixed columns, with extras separately visible."""
	assert_equal(Forage.FORAGE_CLAIM_CAPACITY, EXPECTED_CLAIM_CAPACITY,
		"claim rows are the 8192 Job rows")
	assert_equal(Forage.FORAGE_CLAIM_CAPACITY,
		EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_JOB],
		"and the directory reserves KIND_JOB at exactly that many")
	assert_equal(_forage.claim_payload_bytes(), EXPECTED_CLAIM_PAYLOAD_BYTES,
		"the claim payload is 303104 bytes")
	assert_equal(_forage.quota_addition_bytes(), EXPECTED_QUOTA_ADDITION_BYTES,
		"the specified quota additions total 305280 bytes")
	assert_equal(_forage.extra_ordering_buffer_bytes(), EXPECTED_ORDERING_BUFFER_BYTES,
		"and the two release-order columns are 131072 bytes counted outside that total")


func test_the_claim_readers_refuse_an_empty_row_rather_than_describing_one() -> void:
	"""A refusal never carries a usable number, so an ignored one cannot surface a plausible claim."""
	_use_job_store()
	assert_false(_forage.is_claim_active(-1), "a negative row holds nothing")
	assert_false(_forage.is_claim_active(EXPECTED_CLAIM_CAPACITY), "nor does one past the end")
	assert_false(_forage.claim_remaining_milli_of(0).ok, "an empty row reports no quantity")
	assert_equal(_forage.claim_remaining_milli_of(0).error, "CLAIM_NOT_PRESENT", "with the code")
	assert_false(_forage.claim_kind_of(0).ok, "nor a kind")
	assert_false(_forage.claim_created_tick_of(0).ok, "nor a created tick")
	assert_false(_forage.claim_persistent_id_of(0).ok, "nor a persistent id")
	assert_equal(_forage.claim_job_ref_of(0), NULL_REF, "and its references are null")
	assert_equal(_forage.claim_designation_ref_of(0), NULL_REF, "designation")
	assert_equal(_forage.claim_basin_ref_of(0), NULL_REF, "basin")


func test_a_cut_releases_as_many_whole_claims_as_it_takes() -> void:
	"""§4.5 releases newest-first "until the remaining claims fit", which is often more than one."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 12000)
	var oldest: int = _forage.claim_forage(_make_job(100), basin, BERRIES, 3000, SUMMER,
		false).value
	var middle: int = _forage.claim_forage(_make_job(200), basin, BERRIES, 3000, SUMMER,
		false).value
	var newest: int = _forage.claim_forage(_make_job(300), basin, BERRIES, 3000, SUMMER,
		false).value
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 9000, "9000 is outstanding")
	assert_equal(_forage.claims_released_by_quota(basin, 3000, SUMMER).value, 2,
		"the preview says two jobs are affected")
	assert_equal(_forage.set_quota_milli(basin, 3000, SUMMER).value, 2,
		"and the cut releases both of them, not just the newest one")
	assert_true(_forage.is_claim_active(oldest), "the oldest claim survives")
	assert_false(_forage.is_claim_active(middle), "the middle one goes")
	assert_false(_forage.is_claim_active(newest), "and so does the newest")
	assert_equal(_forage.quota_reserved_milli_of(_slot(basin)).value, 3000, "leaving 3000 of R")


func test_a_reference_of_another_kind_is_never_read_as_a_claim_owner() -> void:
	"""A claim row is a JOB row; a live reference of some other kind must not index into it.

	Both references below name typed row 0 -- the first zone and the first job -- so a lookup that
	validated liveness without validating KIND would land on this very claim.
	"""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, 10000)
	var job: Vector2i = _make_job(10)
	assert_equal(_slot(basin), 0, "the basin is harvest-zone row 0")
	assert_equal(_job_slot(job), 0, "and the job is job row 0")
	assert_true(_forage.claim_forage(job, basin, BERRIES, 3000, SUMMER, false).ok, "3 U is claimed")
	assert_equal(String(_forage.collect_claim(basin, 100, SUMMER, false).error), "JOB_NOT_PRESENT",
		"a harvest-zone reference cannot collect that claim")
	assert_equal(String(_forage.release_claim(basin).error), "JOB_NOT_PRESENT",
		"nor release it")
	assert_equal(String(_forage.claim_forage(basin, basin, NUTS, 100, SUMMER, false).error),
		"JOB_NOT_PRESENT", "nor own a claim of its own")
	assert_equal(_forage.claim_remaining_milli_of(0).value, 3000, "and the real claim is untouched")


func test_the_affected_job_reader_counts_claims_held_through_a_designation() -> void:
	"""R05-QUOTA-015 on the designation's own limit, not only on the basin's."""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, MANUAL_MAX)
	var designation: Vector2i = _make_designation(basin)
	assert_true(_forage.set_quota_milli(designation, 9000, SUMMER).ok, "the local limit is 9000")
	for tick: int in [100, 200, 300]:
		assert_true(_forage.claim_forage(_make_job(tick), designation, BERRIES, 3000, SUMMER,
			false).ok, "3 U is claimed through the designation")
	assert_equal(_forage.claims_released_by_quota(designation, 9000, SUMMER).value, 0,
		"no cut, no affected jobs")
	assert_equal(_forage.claims_released_by_quota(designation, 5000, SUMMER).value, 2,
		"cutting the DESIGNATION to 5000 affects two of its own jobs")
	assert_equal(_forage.claims_released_by_quota(basin, 5000, SUMMER).value, 2,
		"and the basin sees the same two, because it is their basin")


func test_collection_checks_both_limits_against_a_restored_claim_that_exceeds_one() -> void:
	"""§4.7's load path runs no preflight, so collection-time validation must hold both limits.

	A saved claim larger than a limit is the one state in which `H + amount > Q` can be reached,
	because every admission path already guarantees `H + R <= Q`. Each limit is shown separately.
	"""
	_use_job_store()
	var basin: Vector2i = _make_basin(1, MANUAL_MAX)
	var designation: Vector2i = _make_designation(basin)
	assert_true(_forage.set_quota_milli(designation, 1000, SUMMER).ok, "the local limit is 1 U")
	var job: Vector2i = _make_job(10)
	assert_true(_forage.restore_claim(job, designation, BERRIES, 4000).ok, "a 4 U claim restores")
	assert_equal(_forage.rebuild_reservation_aggregates().value, 1, "and its total rebuilds")
	var over_local: Forage.OpResult = _forage.collect_claim(job, 4000, SUMMER, false)
	assert_false(over_local.ok, "collecting all 4 U breaks the designation's own limit")
	assert_equal(String(over_local.error), "QUOTA_REACHED", "with the quota code")
	assert_true(_forage.collect_claim(job, 1000, SUMMER, false).ok, "1 U inside that limit passes")
	var other_basin: Vector2i = _make_basin(1, 1000)
	var other_zone: Vector2i = _make_designation(other_basin)
	assert_true(_forage.set_quota_milli(other_zone, MANUAL_MAX, SUMMER).ok, "a lax designation")
	var other_job: Vector2i = _make_job(20)
	assert_true(_forage.restore_claim(other_job, other_zone, BERRIES, 4000).ok, "4 U restores")
	assert_true(_forage.rebuild_reservation_aggregates().ok, "totals rebuild")
	var over_basin: Forage.OpResult = _forage.collect_claim(other_job, 4000, SUMMER, false)
	assert_false(over_basin.ok, "and the BASIN's 1 U limit stops that one")
	assert_equal(String(over_basin.error), "QUOTA_REACHED", "with the same code")
