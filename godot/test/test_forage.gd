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

var _forage: Forage = null


func before_each() -> void:
	"""Build a forage store owning a private entity directory."""
	_forage = Forage.new()


func after_each() -> void:
	"""Drop the store built for the test."""
	_forage = null


func _make_zone(zone_type: int, danger: int, quota_milli: int) -> Vector2i:
	"""Designate one enabled, unprotected zone and hand back its reference."""
	var made: Forage.OpResult = _forage.create_zone(zone_type, danger, quota_milli, false, true)
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
	assert_equal(_forage.remaining_quota_milli(player_zone, BERRIES).value, 0,
		"the second zone inherits the exhausted quota")
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
	"""§5.1 gives the quota to the basin; §4.2 gives every zone one. The minimum honours both."""
	var basin: Vector2i = _make_basin(1, 30000)
	var generous: Vector2i = _make_zone(ZONE_FORAGE, 1, 90000)
	_forage.set_basin(generous, basin)
	assert_equal(_forage.effective_quota_milli(generous).value, 30000, "the basin's is stricter")
	var mean: Vector2i = _make_zone(ZONE_FORAGE, 1, 5000)
	_forage.set_basin(mean, basin)
	assert_equal(_forage.effective_quota_milli(mean).value, 5000, "the zone's own is stricter")
	assert_equal(_forage.effective_quota_milli(basin).value, 30000, "a basin uses its own")


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
	assert_false(_forage.is_quota_reached(basin, BERRIES), "the quota starts unspent")
	assert_true(_forage.harvest(basin, BERRIES, 30000, SUMMER, false).ok, "30 U is taken")
	assert_equal(_forage.remaining_quota_milli(basin, BERRIES).value, 20000, "20 U remains")
	var over: Forage.OpResult = _forage.harvest(basin, BERRIES, 25000, SUMMER, false)
	assert_false(over.ok, "a 25 U request over a 20 U remainder is refused, not clamped")
	assert_equal(String(over.error), "QUOTA_REACHED", "with the quota code")
	assert_true(_forage.harvest(basin, BERRIES, 20000, SUMMER, false).ok, "20 U exactly fits")
	assert_true(_forage.is_quota_reached(basin, BERRIES), "and the quota is now reached")


func test_a_zero_quota_permits_nothing() -> void:
	"""The document states no "unlimited" encoding, so 0 is read as a zero budget."""
	var basin: Vector2i = _make_basin(1, 0)
	assert_true(_forage.is_quota_reached(basin, BERRIES), "a zero quota is reached immediately")
	var refused: Forage.OpResult = _forage.harvest(basin, BERRIES, 1, SUMMER, false)
	assert_false(refused.ok, "and nothing can be taken")
	assert_equal(String(refused.error), "QUOTA_REACHED", "with the quota code")


func test_the_year_accumulator_is_reset_by_its_owner() -> void:
	"""`harvested_year_milli` is the only accumulator in the forage schema (module header)."""
	var basin: Vector2i = _make_basin(1, 50000)
	var row: int = _forage.patch_row_for_zone(basin, BERRIES).value
	_forage.harvest(basin, BERRIES, 50000, SUMMER, false)
	assert_equal(_forage.harvested_year_milli_of(row).value, 50000, "50 U was taken this year")
	_forage.reset_harvested_year()
	assert_equal(_forage.harvested_year_milli_of(row).value, 0, "the year total is cleared")
	assert_false(_forage.is_quota_reached(basin, BERRIES), "and the quota opens again")
	assert_equal(_forage.stock_milli_of(row).value, BERRIES_INITIAL - 50000,
		"but the stock is not refilled by a new year")


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
