extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/orchard_hive.gd` — the OrchardPlot and Hive stores and the
## HivePollinationLinks table of ruling `2026-09-09_ready06_open_item_answers.md` §3.
##
## Every acceptance item ruling §3 names is a test below, under its own name:
##   * first/last farm and orchard rows do not collide
##     (`test_first_and_last_farm_and_orchard_link_rows_do_not_collide`,
##      `test_a_farm_refresh_cannot_write_into_the_first_orchard_slice`);
##   * six entries per owner never spill into the next
##     (`test_six_links_never_spill_into_the_neighbouring_slices`);
##   * exactly 12 m qualifies and one coordinate unit beyond does not
##     (`test_exactly_twelve_metres_qualifies_and_one_unit_beyond_does_not`,
##      `test_a_hive_exactly_twelve_metres_away_is_linked_and_thirteen_is_not`);
##   * the 0/1/2/7 healthy-hive cases (`test_zero_one_two_and_seven_healthy_hives_*`);
##   * health crossing 4999/5000 changes eligibility
##     (`test_strength_crossing_4999_and_5000_changes_eligibility`);
##   * removing a cached hive discovers a previously seventh candidate
##     (`test_removing_a_cached_hive_discovers_the_previously_seventh_candidate`);
##   * duplicate and stale references fail (`test_a_duplicated_link_fails_validation`,
##     `test_a_stale_link_refuses_the_yield_read_rather_than_repairing_it`);
##   * owner reuse cannot inherit links (`test_a_reused_orchard_row_cannot_inherit_links`,
##     `test_a_cleared_farm_recipient_cannot_inherit_links`).
##
## GEOMETRY USED BY THE LINK TESTS. The crop tile is (10, 10), whose centre is
## `(10 + 10 + 1) * 1024 = 21504` on both axes. A 1x1 hive footprint on tile x has centre
## `(2x + 1) * 1024`, so tile 11 is 2048 units away, tile 16 exactly 12288 (12 m) and tile 17
## 14336. A 2-tile-wide footprint centres on a tile BOUNDARY -- `(16 + 17 + 1) * 1024 = 34816` --
## which is how the even-dimension case is exercised without rounding.
##
## The exterior tile lattice quantises every achievable distance to a multiple of 1024, so "one
## coordinate unit beyond 12 m" cannot be produced by any real footprint. It is therefore asserted
## on the range predicate and the squared-distance reader directly, and the store-level test uses
## the nearest achievable pair either side of the boundary. Both halves are present deliberately.
##
## Hive footprints in these tests may overlap each other. This store models no building collision:
## `Hive.building` points at a Building store that does not exist, and placement is not its
## contract. Where a test needs non-overlapping hives it uses distinct tiles.

const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")

## Absolute days. Day 1 is spring 1 of year 1; the calendar is 12 days/season, 48 days/year.
const DAY_ONE: int = 1
const SUMMER_DAY_ONE: int = 13
const AUTUMN_DAY_ONE: int = 25
const WINTER_DAY_ONE: int = 37
const YEAR_TWO_DAY_ONE: int = 49
## Year 3 autumn day 1, which is the first apple harvest of a tree planted on day 1.
const APPLE_FIRST_HARVEST_DAY: int = 121

const CROP_X: int = 10
const CROP_Z: int = 10
const CROP_CENTER: int = 21504
const FARM_ROW: int = 3
const LAST_FARM_ROW: int = 4095

## A temperature that is not a chill day, in tenths: 6.0 degC.
const MILD_TENTHS: int = 60
## A chill day at exactly §5.6's "temperature<=5degC" boundary.
const CHILL_TENTHS: int = 50

var _dir: EntityDirectoryScript = null
var _store: OrchardHiveScript = null
var _out: IntMathScript.IntResult = null


func before_each() -> void:
	"""Build an empty store over its own directory and one reusable arithmetic result."""
	_dir = EntityDirectoryScript.new()
	_store = OrchardHiveScript.new(_dir)
	_out = IntMathScript.IntResult.new()


func _new_building() -> Vector2i:
	"""Allocate a directory row of kind BUILDING to own a hive. No Building STORE exists."""
	return _dir.create(EntityDirectoryScript.KIND_BUILDING)


func _hive_at(tile_x: int, tile_z: int) -> Vector2i:
	"""Create a live hive on a 1x1 apiary footprint at one tile, at full starting strength."""
	var result: OrchardHiveScript.OpResult = _store.create_hive(
		_new_building(), tile_x, tile_z, tile_x, tile_z, DAY_ONE)
	assert_true(result.ok, "the fixture hive must be created (%s)" % result.error)
	return result.ref


func _wide_hive(min_x: int, max_x: int, min_z: int, max_z: int) -> Vector2i:
	"""Create a live hive on a multi-tile apiary footprint, for the even-dimension cases."""
	var result: OrchardHiveScript.OpResult = _store.create_hive(
		_new_building(), min_x, min_z, max_x, max_z, DAY_ONE)
	assert_true(result.ok, "the fixture hive must be created (%s)" % result.error)
	return result.ref


func _plant_apple(origin_x: int, origin_z: int, day: int) -> Vector2i:
	"""Plant one apple block and return its reference."""
	var result: OrchardHiveScript.OpResult = _store.plant_orchard(
		origin_x, origin_z, OrchardHiveScript.SPECIES_APPLE, day)
	assert_true(result.ok, "the fixture orchard must be planted (%s)" % result.error)
	return result.ref


func _row_of(orchard_ref: Vector2i) -> int:
	"""The typed row of a live orchard reference, for the row-indexed readers."""
	var row: IntMathScript.IntResult = _store.orchard_row_of(orchard_ref)
	assert_true(row.ok, "the fixture orchard reference must resolve")
	return row.value


func _farm_link_slot(farm_row: int, link_index: int) -> int:
	"""The stored hive slot of one FarmPlot link entry."""
	var link: OrchardHiveScript.OpResult = _store.farm_link_at(farm_row, link_index)
	assert_true(link.ok, "a link entry inside the slice must read")
	return link.ref.x


func _orchard_link_slot(orchard_row: int, link_index: int) -> int:
	"""The stored hive slot of one orchard link entry."""
	var link: OrchardHiveScript.OpResult = _store.orchard_link_at(orchard_row, link_index)
	assert_true(link.ok, "a link entry inside the slice must read")
	return link.ref.x


func _farm_count(farm_row: int) -> int:
	"""Eligible linked hives for a FarmPlot row; fails the test if the slice refuses."""
	assert_true(_store.farm_hive_count_into(farm_row, _out),
		"the farm slice must be readable (%s)" % _out.error)
	return _out.value


# --- ruling §3: the owner-major index ------------------------------------------------------------

func test_first_and_last_farm_and_orchard_link_rows_do_not_collide() -> void:
	"""Farm rows 0/4095 and orchard rows 0/1023 occupy four disjoint slices of the 30720 table."""
	assert_equal(_store.recipient_index_of_farm_row(0).value, 0, "farm row 0 is recipient 0")
	assert_equal(_store.recipient_index_of_farm_row(LAST_FARM_ROW).value, 4095,
		"farm row 4095 is recipient 4095")
	assert_equal(_store.recipient_index_of_orchard_row(0).value, 4096,
		"ruling §3: orchard row 0 is recipient 4096, NOT recipient 0")
	assert_equal(_store.recipient_index_of_orchard_row(1023).value, 5119,
		"orchard row 1023 is the last recipient")
	assert_equal(_store.link_row_of(0, 0).value, 0, "farm row 0 starts at link row 0")
	assert_equal(_store.link_row_of(4095, 5).value, 24575,
		"farm row 4095 ends at link row 24575, the last row of the superseded table")
	assert_equal(_store.link_row_of(4096, 0).value, 24576,
		"orchard row 0 starts where the farm block ends")
	assert_equal(_store.link_row_of(5119, 5).value, 30719,
		"orchard row 1023 ends at the last of the 30720 references")
	assert_equal(OrchardHiveScript.LINK_CAPACITY, 30719 + 1, "30720 references exactly")


func test_the_link_table_is_ruling_three_s_stated_capacity_and_payload() -> void:
	"""The columns are 30720 long and the stated +49152-byte delta is what these constants give."""
	var slots: PackedInt32Array = _store.get("_link_hive_slot")
	var generations: PackedInt32Array = _store.get("_link_hive_generation")
	assert_equal(slots.size(), 30720, "the hive-slot column is 30720 entries")
	assert_equal(generations.size(), 30720, "the hive-generation column is 30720 entries")
	assert_equal(OrchardHiveScript.LINK_PAYLOAD_BYTES, 245760, "ruling §3: 245760 payload bytes")
	assert_equal(OrchardHiveScript.LINK_PAYLOAD_DELTA_BYTES, 49152,
		"ruling §3: +49152 over the 24576-row/196608-byte table")
	assert_equal(OrchardHiveScript.LEGACY_LINK_PAYLOAD_BYTES + 49152, 245760,
		"the superseded payload plus the delta is the new payload")
	assert_equal(OrchardHiveScript.CANDIDATE_SCRATCH_BYTES, 120,
		"ruling §3: 120 scratch bytes, counted separately from the payload")


func test_consecutive_recipients_are_exactly_six_rows_apart() -> void:
	"""The stride is 6: one recipient's last row is immediately before the next one's first."""
	var samples: Array[int] = [0, 1, 4094, 4095, 4096, 4097, 5118]
	for recipient: int in samples:
		var last: int = _store.link_row_of(recipient, 5).value
		var next_first: int = _store.link_row_of(recipient + 1, 0).value
		assert_equal(next_first, last + 1, "recipient %d must abut the next" % recipient)
	assert_equal(_store.link_row_of(5119, 5).value, OrchardHiveScript.LINK_CAPACITY - 1,
		"the last recipient's last entry is the last row of the table")


func test_link_row_refuses_an_index_outside_the_six_entry_slice() -> void:
	"""A seventh entry names no row and is refused rather than silently addressing the neighbour."""
	assert_false(_store.link_row_of(0, 6).ok, "link index 6 is outside the six-entry slice")
	assert_false(_store.link_row_of(0, -1).ok, "a negative link index names no entry")
	assert_false(_store.link_row_of(5120, 0).ok, "recipient 5120 is past the last recipient")
	assert_false(_store.recipient_index_of_farm_row(4096).ok, "farm row 4096 does not exist")
	assert_false(_store.recipient_index_of_orchard_row(1024).ok, "orchard row 1024 does not exist")


func test_a_farm_refresh_cannot_write_into_the_first_orchard_slice() -> void:
	"""The bug U6 left open: under the 24576-row arithmetic orchard row 0 aliased farm row 0."""
	_hive_at(11, 10)
	assert_true(_store.refresh_farm_links(0, CROP_X, CROP_Z).ok, "farm row 0 refreshes")
	assert_equal(_farm_count(0), 1, "farm row 0 links its one hive")
	for link_index: int in OrchardHiveScript.LINKS_PER_RECIPIENT:
		assert_equal(_orchard_link_slot(0, link_index), EntityDirectoryScript.NULL_SLOT,
			"orchard row 0 must be untouched by a farm row 0 refresh")


func test_six_links_never_spill_into_the_neighbouring_slices() -> void:
	"""A full six-entry slice leaves the recipient before it and the one after it empty."""
	_seven_hives_around_the_crop_tile()
	assert_true(_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z).ok, "the slice refreshes")
	assert_equal(_farm_count(FARM_ROW), 6, "six of the seven eligible hives are retained")
	for link_index: int in OrchardHiveScript.LINKS_PER_RECIPIENT:
		assert_equal(_farm_link_slot(FARM_ROW - 1, link_index), EntityDirectoryScript.NULL_SLOT,
			"the previous recipient's slice stays empty")
		assert_equal(_farm_link_slot(FARM_ROW + 1, link_index), EntityDirectoryScript.NULL_SLOT,
			"the next recipient's slice stays empty")


func test_the_last_farm_slice_does_not_spill_into_the_first_orchard_slice() -> void:
	"""Recipient 4095 and recipient 4096 are adjacent, which is where an off-by-one would show."""
	_seven_hives_around_the_crop_tile()
	assert_true(_store.refresh_farm_links(LAST_FARM_ROW, CROP_X, CROP_Z).ok, "row 4095 refreshes")
	assert_equal(_farm_count(LAST_FARM_ROW), 6, "the last farm row links six hives")
	for link_index: int in OrchardHiveScript.LINKS_PER_RECIPIENT:
		assert_equal(_orchard_link_slot(0, link_index), EntityDirectoryScript.NULL_SLOT,
			"orchard row 0 stays empty when the last farm row fills")


# --- ruling §3: the lookup rule and its boundary ----------------------------------------------------

func test_the_footprint_centre_is_the_tile_centre_for_a_single_tile() -> void:
	"""`(min + max + 1) * 1024` with min == max is GDD §5.1's own `2048x + 1024`."""
	assert_equal(_store.footprint_center_units(0, 0).value, 1024, "tile 0 centres at 1024")
	assert_equal(_store.footprint_center_units(10, 10).value, CROP_CENTER, "tile 10 centres at 21504")
	assert_equal(_store.footprint_center_units(127, 127).value, 261120, "tile 127 centres at 261120")
	assert_false(_store.footprint_center_units(0, 128).ok, "tile 128 is off the 128x128 grid")
	assert_false(_store.footprint_center_units(5, 4).ok, "an inverted footprint is refused")


func test_an_even_dimension_footprint_centres_without_rounding() -> void:
	"""A two-tile span centres on the tile boundary between them, exactly, with no midpoint."""
	assert_equal(_store.footprint_center_units(16, 17).value, 34816,
		"tiles 16-17 centre at (16+17+1)*1024 = 34816, a tile boundary")
	assert_equal(_store.footprint_center_units(10, 13).value, 24576,
		"a 4-wide block centres at (10+13+1)*1024 = 24576")
	assert_equal(_store.footprint_center_units(10, 12).value, 23552,
		"a 3-wide span centres on the middle tile's own centre")


func test_exactly_twelve_metres_qualifies_and_one_unit_beyond_does_not() -> void:
	"""Ruling §3's inclusive bound, asserted at the exact squared value and one unit past it."""
	assert_equal(OrchardHiveScript.POLLINATION_RANGE_UNITS, 12288, "12 m at 1024 units/m")
	assert_equal(OrchardHiveScript.POLLINATION_RANGE_SQUARED, 150994944, "12288 squared")
	assert_equal(
		OrchardHiveScript.POLLINATION_RANGE_UNITS * OrchardHiveScript.POLLINATION_RANGE_UNITS,
		OrchardHiveScript.POLLINATION_RANGE_SQUARED,
		"and the two independently stated figures are one another's square")
	assert_true(OrchardHiveScript.is_in_pollination_range(150994944), "exactly 12 m qualifies")
	assert_false(OrchardHiveScript.is_in_pollination_range(150994945),
		"one squared unit beyond 12 m does not qualify")
	assert_equal(_store.squared_distance(0, 0, 12288, 0).value, 150994944, "12 m on one axis")
	assert_true(OrchardHiveScript.is_in_pollination_range(_store.squared_distance(0, 0, 12288, 0).value),
		"a point exactly 12 m away qualifies")
	assert_false(OrchardHiveScript.is_in_pollination_range(_store.squared_distance(0, 0, 12289, 0).value),
		"a point one coordinate unit further does not qualify")
	assert_false(OrchardHiveScript.is_in_pollination_range(-1), "a negative is not a distance")


func test_a_hive_exactly_twelve_metres_away_is_linked_and_thirteen_is_not() -> void:
	"""The same boundary through the store: tile 16 is exactly 12 m from the crop tile, 16-17 is not."""
	var near: Vector2i = _hive_at(16, CROP_Z)
	assert_true(_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z).ok, "the slice refreshes")
	assert_equal(_farm_count(FARM_ROW), 1, "a hive exactly 12288 units away is in range")
	assert_equal(_farm_link_slot(FARM_ROW, 0), near.x, "and it is the hive that was linked")
	assert_true(_store.destroy_hive(near).ok, "remove the boundary hive")
	_wide_hive(16, 17, CROP_Z, CROP_Z)
	assert_true(_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z).ok, "the slice refreshes")
	assert_equal(_farm_count(FARM_ROW), 0,
		"a footprint centred 13312 units away is outside the 12 m range")


func test_the_squared_distance_reader_is_symmetric_and_uses_both_axes() -> void:
	"""`dx*dx + dz*dz`, with no square root and no axis dropped."""
	assert_equal(_store.squared_distance(0, 0, 3, 4).value, 25, "3-4-5 in squared units")
	assert_equal(_store.squared_distance(3, 4, 0, 0).value, 25, "the reader is symmetric")
	assert_equal(_store.squared_distance(0, 0, 0, 4).value, 16, "the z axis alone still counts")
	assert_equal(_store.squared_distance(-2, -2, 1, 2).value, 25, "negative coordinates square")


# --- ruling §3: selection, ordering and the null-filled tail -------------------------------------------

func _seven_hives_around_the_crop_tile() -> Array[Vector2i]:
	"""Seven healthy hives at seven DISTINCT squared distances from crop tile (10, 10).

	Ascending: (11,10) 4194304, (11,11) 8388608, (12,10) 16777216, (12,11) 20971520,
	(12,12) 33554432, (13,10) 37748736, (13,11) 41943040. Created in that order, so the persistent
	IDs ascend with the distance and the sixth/seventh boundary is unambiguous.
	"""
	var hives: Array[Vector2i] = []
	hives.append(_hive_at(11, 10))
	hives.append(_hive_at(11, 11))
	hives.append(_hive_at(12, 10))
	hives.append(_hive_at(12, 11))
	hives.append(_hive_at(12, 12))
	hives.append(_hive_at(13, 10))
	hives.append(_hive_at(13, 11))
	return hives


func test_links_are_ordered_by_ascending_squared_distance() -> void:
	"""Ruling §3's primary order. The six retained hives are the six nearest, nearest first."""
	var hives: Array[Vector2i] = _seven_hives_around_the_crop_tile()
	assert_true(_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z).ok, "the slice refreshes")
	for link_index: int in 6:
		assert_equal(_farm_link_slot(FARM_ROW, link_index), hives[link_index].x,
			"link %d must be the %d-th nearest hive" % [link_index, link_index])


func test_zero_one_two_and_seven_healthy_hives_give_the_stated_factors() -> void:
	"""§5.6's 1000/1100/1150 for beans, and REQ-SET-082's "ignore further hives" at seven."""
	assert_true(_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z).ok, "no hives yet")
	assert_equal(_farm_count(FARM_ROW), 0, "no hive is in range")
	assert_true(_store.farm_pollination_factor_into(FARM_ROW, FarmingScript.CROP_BEANS, _out),
		"the factor reads")
	assert_equal(_out.value, 1000, "no healthy hive gives 1000")
	_hive_at(11, 10)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	_store.farm_pollination_factor_into(FARM_ROW, FarmingScript.CROP_BEANS, _out)
	assert_equal(_out.value, 1100, "one healthy hive gives 1100")
	_hive_at(11, 11)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	_store.farm_pollination_factor_into(FARM_ROW, FarmingScript.CROP_BEANS, _out)
	assert_equal(_out.value, 1150, "two healthy hives give 1150")
	_seven_hives_around_the_crop_tile()
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	_store.farm_pollination_factor_into(FARM_ROW, FarmingScript.CROP_BEANS, _out)
	assert_equal(_out.value, 1150, "seven healthy hives still give 1150 and never more")


func test_the_factor_table_ignores_every_hive_past_the_second() -> void:
	"""REQ-SET-082's bound as a pure function, including the impossible-but-guarded negative."""
	assert_equal(OrchardHiveScript.pollination_factor_for_count(0), 1000, "no hive")
	assert_equal(OrchardHiveScript.pollination_factor_for_count(1), 1100, "one hive")
	assert_equal(OrchardHiveScript.pollination_factor_for_count(2), 1150, "two hives")
	assert_equal(OrchardHiveScript.pollination_factor_for_count(6), 1150, "six hives, still 1150")
	assert_equal(OrchardHiveScript.pollination_factor_for_count(-1), 1000, "no count, no bonus")


func test_an_unpollinated_crop_stays_at_one_thousand_beside_six_hives() -> void:
	"""§5.6 pollinates beans and orchard fruit only; grain beside six hives still pays 1000."""
	_seven_hives_around_the_crop_tile()
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 6, "six hives are linked")
	assert_true(_store.farm_pollination_factor_into(FARM_ROW, FarmingScript.CROP_GRAIN, _out),
		"the grain factor reads")
	assert_equal(_out.value, 1000, "grain is not a pollinated crop")
	assert_true(_store.farm_pollination_factor_into(FARM_ROW, FarmingScript.CROP_FLAX, _out),
		"the flax factor reads")
	assert_equal(_out.value, 1000, "flax is not a pollinated crop")
	assert_true(OrchardHiveScript.is_pollinated_crop(FarmingScript.CROP_BEANS), "beans are")
	assert_false(_store.farm_pollination_factor_into(FARM_ROW, 99, _out), "99 names no crop")


func test_ties_are_broken_by_the_lower_persistent_hive_id() -> void:
	"""Two hives at an identical distance order by persistent ID, whichever was created first."""
	var first: Vector2i = _hive_at(9, 10)
	var second: Vector2i = _hive_at(11, 10)
	assert_equal(_store.squared_distance(CROP_CENTER, CROP_CENTER,
		_store.hive_center_x_of(_dir.get_typed_row(first)).value, CROP_CENTER).value,
		_store.squared_distance(CROP_CENTER, CROP_CENTER,
		_store.hive_center_x_of(_dir.get_typed_row(second)).value, CROP_CENTER).value,
		"the two fixture hives are exactly the same distance away")
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_true(_dir.get_persistent_id(first) < _dir.get_persistent_id(second),
		"the first-created hive holds the lower persistent ID")
	assert_equal(_farm_link_slot(FARM_ROW, 0), first.x, "the lower persistent ID sorts first")
	assert_equal(_farm_link_slot(FARM_ROW, 1), second.x, "the higher persistent ID follows")


func test_the_tiebreak_is_the_persistent_id_and_not_the_directory_slot() -> void:
	"""A reused directory slot carries a NEW higher persistent ID, and must sort after, not before.

	Built so the two orderings disagree: the surviving hive holds the lower persistent ID while
	the replacement holds the lower directory slot.
	"""
	var doomed: Vector2i = _hive_at(9, 10)
	var survivor: Vector2i = _hive_at(11, 10)
	var replacement_building: Vector2i = _new_building()
	assert_true(_store.destroy_hive(doomed).ok, "free the earlier directory slot")
	var replacement: OrchardHiveScript.OpResult = _store.create_hive(
		replacement_building, 9, 10, 9, 10, DAY_ONE)
	assert_true(replacement.ok, "the replacement hive is created into the freed slot")
	assert_true(replacement.ref.x < survivor.x, "the replacement holds the LOWER directory slot")
	assert_true(_dir.get_persistent_id(replacement.ref) > _dir.get_persistent_id(survivor),
		"the replacement holds the HIGHER persistent ID")
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_link_slot(FARM_ROW, 0), survivor.x,
		"the tiebreak is the persistent ID, so the survivor sorts first")
	assert_equal(_farm_link_slot(FARM_ROW, 1), replacement.ref.x, "and the replacement follows")


func test_unused_link_entries_are_null_filled() -> void:
	"""Two hives fill entries 0 and 1; entries 2..5 are the empty reference `(-1, 0)`."""
	_hive_at(11, 10)
	_hive_at(11, 11)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 2, "two hives are linked")
	for link_index: int in range(2, OrchardHiveScript.LINKS_PER_RECIPIENT):
		var link: OrchardHiveScript.OpResult = _store.farm_link_at(FARM_ROW, link_index)
		assert_equal(link.ref, EntityDirectoryScript.NULL_REF,
			"entry %d is the empty reference" % link_index)


func test_a_shrinking_selection_rewrites_the_tail_instead_of_keeping_stale_entries() -> void:
	"""Six hives then one: entries 1..5 must be re-nulled, not left holding the removed hives."""
	var hives: Array[Vector2i] = _seven_hives_around_the_crop_tile()
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 6, "six hives are linked first")
	for index: int in range(1, hives.size()):
		assert_true(_store.destroy_hive(hives[index]).ok, "remove all but the nearest hive")
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 1, "one hive remains linked")
	for link_index: int in range(1, OrchardHiveScript.LINKS_PER_RECIPIENT):
		assert_equal(_farm_link_slot(FARM_ROW, link_index), EntityDirectoryScript.NULL_SLOT,
			"entry %d was re-nulled rather than left stale" % link_index)


# --- ruling §3: health is a filter BEFORE the six-entry buffer ------------------------------------------

func test_strength_crossing_4999_and_5000_changes_eligibility() -> void:
	"""§5.6's healthy line is `>= 5000`: 5000 is eligible, 4999 is not."""
	var hive: Vector2i = _hive_at(11, 10)
	assert_true(_store.restore_hive_state(hive, 5000, 0, 0, 0, DAY_ONE).ok, "set strength 5000")
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 1, "a hive at exactly 5000 is healthy and eligible")
	assert_true(_store.is_hive_healthy(_dir.get_typed_row(hive)), "5000 reads as healthy")
	assert_true(_store.restore_hive_state(hive, 4999, 0, 0, 0, DAY_ONE).ok, "set strength 4999")
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 0, "a hive one point below 5000 is not eligible")
	assert_false(_store.is_hive_healthy(_dir.get_typed_row(hive)), "4999 does not read as healthy")


func test_six_unhealthy_neighbours_do_not_hide_a_qualifying_seventh_hive() -> void:
	"""Ruling §3's named error: caching the nearest six regardless of health loses the seventh."""
	var hives: Array[Vector2i] = _seven_hives_around_the_crop_tile()
	for index: int in 6:
		assert_true(_store.restore_hive_state(hives[index], 4999, 0, 0, 0, DAY_ONE).ok,
			"the six nearest hives are unhealthy")
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 1, "only the healthy seventh hive is linked")
	assert_equal(_farm_link_slot(FARM_ROW, 0), hives[6].x, "and it is the seventh hive itself")
	assert_true(_store.farm_pollination_factor_into(FARM_ROW, FarmingScript.CROP_BEANS, _out),
		"the factor reads")
	assert_equal(_out.value, 1100, "one qualifying hive, so 1100 rather than 1000")


func test_removing_a_cached_hive_discovers_the_previously_seventh_candidate() -> void:
	"""Ruling §3's acceptance case, exactly: the seventh hive appears once a cached one is gone."""
	var hives: Array[Vector2i] = _seven_hives_around_the_crop_tile()
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 6, "six of seven are cached")
	assert_false(_farm_link_slot(FARM_ROW, 5) == hives[6].x, "the seventh is NOT cached yet")
	assert_true(_store.destroy_hive(hives[0]).ok, "remove the nearest cached hive")
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 6, "six hives are linked again")
	assert_equal(_farm_link_slot(FARM_ROW, 5), hives[6].x,
		"the previously seventh candidate now occupies the last entry")


func test_an_out_of_range_hive_is_never_linked_however_healthy() -> void:
	"""Range is a filter of its own: a full-strength hive 14336 units away is not linked."""
	_hive_at(17, CROP_Z)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 0, "14336 units is outside the 12 m range")
	assert_true(_store.farm_pollination_factor_into(FARM_ROW, FarmingScript.CROP_BEANS, _out),
		"the factor still reads")
	assert_equal(_out.value, 1000, "and pays the neutral factor")


# --- ruling §3: stale, duplicated and inherited slices --------------------------------------------------

func test_a_stale_link_refuses_the_yield_read_rather_than_repairing_it() -> void:
	"""A destroyed hive leaves a farm slice stale; the read refuses and does NOT recompute."""
	var hive: Vector2i = _hive_at(11, 10)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 1, "the hive is linked")
	assert_true(_store.destroy_hive(hive).ok, "destroy it without refreshing the farm slice")
	assert_false(_store.farm_hive_count_into(FARM_ROW, _out), "the count refuses")
	assert_equal(_out.error, String(OrchardHiveScript.REFUSE_LINKS_STALE), "with the stale code")
	assert_false(_store.farm_pollination_factor_into(FARM_ROW, FarmingScript.CROP_BEANS, _out),
		"and so does the factor a yield would use")
	assert_equal(_farm_link_slot(FARM_ROW, 0), hive.x, "the read repaired nothing")
	assert_false(_store.check_farm_links(FARM_ROW, CROP_X, CROP_Z),
		"and the canonical check reports the slice as out of date")


func test_an_ineligible_linked_hive_refuses_the_read_until_the_slice_is_refreshed() -> void:
	"""A cached hive that fell below 5000 cannot keep paying a multiplier it no longer earns."""
	var hive: Vector2i = _hive_at(11, 10)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	var columns: PackedInt32Array = _store.get("_h_strength")
	columns[_dir.get_typed_row(hive)] = 4999
	_store.set("_h_strength", columns)
	assert_false(_store.farm_hive_count_into(FARM_ROW, _out), "the stale slice refuses")
	assert_equal(_out.error, String(OrchardHiveScript.REFUSE_LINKS_STALE), "with the stale code")
	assert_true(_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z).ok, "refresh the slice")
	assert_equal(_farm_count(FARM_ROW), 0, "after which the hive is gone from the slice")


func test_a_duplicated_link_fails_validation() -> void:
	"""One hive may appear at most once in a slice; a repeated reference is refused, not counted."""
	var hive: Vector2i = _hive_at(11, 10)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	var slots: PackedInt32Array = _store.get("_link_hive_slot")
	var generations: PackedInt32Array = _store.get("_link_hive_generation")
	var base: int = _store.link_row_of(FARM_ROW, 0).value
	slots[base + 1] = slots[base]
	generations[base + 1] = generations[base]
	_store.set("_link_hive_slot", slots)
	_store.set("_link_hive_generation", generations)
	assert_false(_store.is_slice_valid(FARM_ROW), "the duplicated slice is invalid")
	assert_false(_store.farm_hive_count_into(FARM_ROW, _out), "and the count refuses")
	assert_equal(_out.error, String(OrchardHiveScript.REFUSE_LINKS_STALE), "with the stale code")
	assert_true(_dir.is_valid_of_kind(hive, EntityDirectoryScript.KIND_HIVE), "the hive itself is fine")


func test_a_hole_before_a_link_fails_validation() -> void:
	"""The empty entries are a suffix: a null followed by a live reference is not a valid slice."""
	_hive_at(11, 10)
	_hive_at(11, 11)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_true(_store.is_slice_valid(FARM_ROW), "the freshly written slice is valid")
	var slots: PackedInt32Array = _store.get("_link_hive_slot")
	var base: int = _store.link_row_of(FARM_ROW, 0).value
	slots[base] = EntityDirectoryScript.NULL_SLOT
	_store.set("_link_hive_slot", slots)
	assert_false(_store.is_slice_valid(FARM_ROW), "a hole before a live link is invalid")


func test_a_cleared_farm_recipient_cannot_inherit_links() -> void:
	"""`clear_farm_links()` is the FarmPlot lifecycle's obligation on destroy and on row reuse."""
	_hive_at(11, 10)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_farm_count(FARM_ROW), 1, "the outgoing plot linked one hive")
	assert_true(_store.clear_farm_links(FARM_ROW).ok, "the lifecycle clears the slice")
	assert_equal(_farm_count(FARM_ROW), 0, "the reused row inherits nothing")
	for link_index: int in OrchardHiveScript.LINKS_PER_RECIPIENT:
		assert_equal(_farm_link_slot(FARM_ROW, link_index), EntityDirectoryScript.NULL_SLOT,
			"every entry of the cleared slice is empty")
	assert_false(_store.clear_farm_links(4096).ok, "and a row that does not exist is refused")


func test_a_reused_orchard_row_cannot_inherit_links() -> void:
	"""This store owns the orchard lifecycle, so removal clears the slice, including on reuse."""
	_hive_at(11, 10)
	var first: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(first)
	assert_true(_store.orchard_hive_count_into(row, _out), "the block's slice reads")
	assert_equal(_out.value, 1, "the planted block linked the nearby hive")
	assert_true(_store.remove_orchard(first).ok, "remove the block")
	for link_index: int in OrchardHiveScript.LINKS_PER_RECIPIENT:
		assert_equal(_orchard_link_slot(row, link_index), EntityDirectoryScript.NULL_SLOT,
			"the removed block's slice was cleared")
	var second: Vector2i = _plant_apple(60, 60, DAY_ONE)
	assert_equal(_row_of(second), row, "the new block reuses the freed typed row")
	assert_true(_store.orchard_hive_count_into(row, _out), "the new block's slice reads")
	assert_equal(_out.value, 0, "and it inherited none of the previous block's links")


func test_a_stale_orchard_reference_reaches_no_row() -> void:
	"""A reference to a removed block is refused rather than resolving to whoever reused the row."""
	var first: Vector2i = _plant_apple(10, 10, DAY_ONE)
	assert_true(_store.remove_orchard(first).ok, "remove the block")
	_plant_apple(10, 10, DAY_ONE)
	assert_false(_store.orchard_row_of(first).ok, "the stale reference resolves to no row")
	assert_false(_store.refresh_orchard_links(first).ok, "and refreshes nothing")
	assert_false(_store.harvest_orchard(first, APPLE_FIRST_HARVEST_DAY).ok, "and harvests nothing")


# --- §5.6's orchard table, transcribed and checked ---------------------------------------------------

func test_the_orchard_table_is_transcribed_exactly() -> void:
	"""§5.6: apple 4x4/96 days/80 U/Autumn 1-6, pear 4x4/144 days/110 U/Autumn 3-8."""
	assert_equal(_store.maturity_days_of(OrchardHiveScript.SPECIES_APPLE).value, 96, "apple 96 days")
	assert_equal(_store.maturity_days_of(OrchardHiveScript.SPECIES_PEAR).value, 144, "pear 144 days")
	assert_equal(_store.annual_yield_milli_of(OrchardHiveScript.SPECIES_APPLE).value, 80000,
		"apple 80 fruit U/year")
	assert_equal(_store.annual_yield_milli_of(OrchardHiveScript.SPECIES_PEAR).value, 110000,
		"pear 110 fruit U/year")
	assert_equal(_store.harvest_first_day_of(OrchardHiveScript.SPECIES_APPLE).value, 1, "apple autumn 1")
	assert_equal(_store.harvest_last_day_of(OrchardHiveScript.SPECIES_APPLE).value, 6, "apple autumn 6")
	assert_equal(_store.harvest_first_day_of(OrchardHiveScript.SPECIES_PEAR).value, 3, "pear autumn 3")
	assert_equal(_store.harvest_last_day_of(OrchardHiveScript.SPECIES_PEAR).value, 8, "pear autumn 8")
	assert_equal(OrchardHiveScript.BLOCK_SIZE, 4, "both species occupy a 4x4 block")


func test_the_orchard_costs_and_care_figures_are_transcribed_exactly() -> void:
	"""§5.6's plant cost, care, removal, health steps and nursery propagation."""
	assert_equal(OrchardHiveScript.PLANT_SAPLING_MILLI, 1000, "sapling 1 per block")
	assert_equal(OrchardHiveScript.PLANT_COMPOST_MILLI, 4000, "compost 4 per block")
	assert_equal(OrchardHiveScript.CARE_WORK_MILLI_WU, 20000, "20 WU/day in spring/summer")
	assert_equal(OrchardHiveScript.CARE_DROUGHT_WATER_MILLI, 2000, "water 2 U/day during drought")
	assert_equal(OrchardHiveScript.UNTENDED_HEALTH_LOSS, 100, "untended days remove 100 health")
	assert_equal(OrchardHiveScript.TENDED_HEALTH_GAIN, 50, "tended days restore 50")
	assert_equal(OrchardHiveScript.REMOVAL_WOOD_MILLI, 8000, "removal yields wood 8")
	assert_equal(OrchardHiveScript.NURSERY_FRUIT_MILLI, 4000, "nursery fruit 4")
	assert_equal(OrchardHiveScript.NURSERY_COMPOST_MILLI, 2000, "nursery compost 2")
	assert_equal(OrchardHiveScript.NURSERY_WATER_MILLI, 2000, "nursery water 2")
	assert_equal(OrchardHiveScript.NURSERY_WORK_MILLI_WU, 120000, "nursery 120 WU")
	assert_equal(OrchardHiveScript.NURSERY_WAIT_DAYS, 12, "nursery 12-day wait")
	assert_equal(OrchardHiveScript.MILESTONE_STARTER_SAPLINGS, 2, "M3 grants two of each sapling")


func test_the_named_item_keys_exist_in_the_compiled_catalog() -> void:
	"""Every item key this store names resolves in the real ItemDefinition catalog, not a copy."""
	var inventory: InventoryScript = InventoryScript.new(8, 256)
	var definitions: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(definitions.load_default(inventory).ok, "the real catalog loads")
	var keys: Array[StringName] = [
		OrchardHiveScript.HONEY_ITEM_KEY, OrchardHiveScript.WAX_ITEM_KEY,
		OrchardHiveScript.FRUIT_ITEM_KEY, OrchardHiveScript.WOOD_ITEM_KEY,
		OrchardHiveScript.COMPOST_ITEM_KEY, OrchardHiveScript.WATER_ITEM_KEY,
		_store.sapling_item_key_of(OrchardHiveScript.SPECIES_APPLE),
		_store.sapling_item_key_of(OrchardHiveScript.SPECIES_PEAR),
	]
	for key: StringName in keys:
		assert_true(definitions.compiled_id(key) >= 0, "item key '%s' must exist" % key)


func test_an_unknown_species_is_refused_rather_than_defaulted() -> void:
	"""There are exactly two species; anything else names no row and refuses."""
	assert_false(_store.maturity_days_of(2).ok, "species 2 does not exist")
	assert_false(_store.maturity_days_of(-1).ok, "SPECIES_NONE names no row")
	assert_equal(_store.species_key_of(7), &"", "an unknown species has no key")
	assert_equal(_store.sapling_item_key_of(7), &"", "an unknown species has no sapling")
	assert_false(_store.plant_orchard(10, 10, 2, DAY_ONE).ok, "and cannot be planted")


# --- REQ-SET-081: the pre-confirmation preview ------------------------------------------------------

func test_the_preview_states_the_first_apple_harvest_of_a_day_one_planting() -> void:
	"""Apple planted day 1 matures day 97, inside year 3, and first harvests autumn 1 of year 3."""
	var preview: OrchardHiveScript.PlantingPreview = _store.preview_planting(
		10, 10, OrchardHiveScript.SPECIES_APPLE, DAY_ONE)
	assert_true(preview.ok, "the preview succeeds (%s)" % preview.error)
	assert_equal(preview.maturity_day, 97, "96 days after day 1")
	assert_equal(preview.first_harvest_day, APPLE_FIRST_HARVEST_DAY, "absolute day 121")
	assert_equal(preview.first_harvest_year, 3, "which is year 3")
	assert_equal(preview.first_harvest_season, OrchardHiveScript.SEASON_AUTUMN, "in autumn")
	assert_equal(preview.first_harvest_season_day, 1, "on the window's first day")
	assert_equal(preview.min_tile_x, 10, "the block starts at the requested origin")
	assert_equal(preview.max_tile_x, 13, "and occupies four tiles on x")
	assert_equal(preview.max_tile_z, 13, "and four on z")


func test_the_preview_states_the_first_pear_harvest_of_a_day_one_planting() -> void:
	"""Pear planted day 1 matures day 145; its window opens on autumn 3, so day 171."""
	var preview: OrchardHiveScript.PlantingPreview = _store.preview_planting(
		20, 20, OrchardHiveScript.SPECIES_PEAR, DAY_ONE)
	assert_true(preview.ok, "the preview succeeds (%s)" % preview.error)
	assert_equal(preview.maturity_day, 145, "144 days after day 1")
	assert_equal(preview.first_harvest_day, 171, "absolute day 171")
	assert_equal(preview.first_harvest_year, 4, "which is year 4")
	assert_equal(preview.first_harvest_season_day, 3, "on the pear window's first day")


func test_a_tree_maturing_inside_its_window_harvests_that_same_year() -> void:
	"""Maturity on autumn day 3 of year 3 is inside apple's 1-6 window, so it does not wait a year."""
	assert_true(_store.first_eligible_harvest_day_into(
		OrchardHiveScript.SPECIES_APPLE, 27, _out), "the reader succeeds")
	assert_equal(_out.value, 123, "maturity day 123 is inside the year 3 window")
	assert_equal(OrchardHiveScript.season_day_of_day(123), 3, "which is autumn day 3")


func test_a_tree_maturing_on_the_window_s_last_day_harvests_that_day() -> void:
	"""The window's closing day is inclusive, so maturity on it is not a year's wait."""
	assert_true(_store.first_eligible_harvest_day_into(
		OrchardHiveScript.SPECIES_APPLE, 30, _out), "the reader succeeds")
	assert_equal(_out.value, 126, "maturity day 126 is apple's last window day")
	assert_equal(OrchardHiveScript.season_day_of_day(126), 6, "which is autumn day 6")
	assert_true(_store.first_eligible_harvest_day_into(
		OrchardHiveScript.SPECIES_PEAR, 32, _out), "and for pear")
	assert_equal(_out.value, 176, "whose window closes on autumn day 8")
	assert_equal(OrchardHiveScript.season_day_of_day(176), 8, "which is that day")


func test_a_tree_maturing_after_its_window_waits_for_the_next_year() -> void:
	"""REQ-SET-079: no previous year's fruit is back-filled, so a missed window costs a full year."""
	assert_true(_store.first_eligible_harvest_day_into(
		OrchardHiveScript.SPECIES_APPLE, 31, _out), "the reader succeeds")
	assert_equal(_out.value, 169, "maturity day 127 is past autumn 6, so the wait is to year 4")
	assert_equal(OrchardHiveScript.year_of_day(169), 4, "which is year 4")
	assert_equal(OrchardHiveScript.season_day_of_day(169), 1, "on the window's first day")


func test_the_preview_refuses_exactly_what_the_planting_would_refuse() -> void:
	"""A preview that succeeds describes a planting the store accepts; a refusal names the blocker."""
	_plant_apple(10, 10, DAY_ONE)
	var overlap: OrchardHiveScript.PlantingPreview = _store.preview_planting(
		13, 13, OrchardHiveScript.SPECIES_APPLE, DAY_ONE)
	assert_false(overlap.ok, "an overlapping block previews as refused")
	assert_equal(overlap.error, OrchardHiveScript.REFUSE_BLOCK_OCCUPIED, "with the occupied code")
	assert_false(_store.plant_orchard(13, 13, OrchardHiveScript.SPECIES_APPLE, DAY_ONE).ok,
		"and the planting refuses for the same reason")
	var off_grid: OrchardHiveScript.PlantingPreview = _store.preview_planting(
		125, 10, OrchardHiveScript.SPECIES_APPLE, DAY_ONE)
	assert_false(off_grid.ok, "a block running off the 128x128 grid previews as refused")
	assert_equal(off_grid.error, OrchardHiveScript.REFUSE_INVALID_BLOCK, "with the block code")
	assert_equal(off_grid.first_harvest_day, 0, "and carries no plausible-looking date")


func test_a_block_that_only_touches_another_is_allowed() -> void:
	"""Adjacent blocks are legal on BOTH sides; the overlap test is a rectangle test.

	Both disjunctions of the rectangle test are exercised: a block beginning where the existing
	one ends, and one ending where the existing one begins. A strict comparison on either side
	refuses a legal planting.
	"""
	_plant_apple(10, 10, DAY_ONE)
	assert_true(_store.is_block_free(14, 10), "the block starting one tile past is free")
	assert_true(_store.plant_orchard(14, 10, OrchardHiveScript.SPECIES_PEAR, DAY_ONE).ok,
		"and can be planted")
	assert_true(_store.is_block_free(6, 10), "the block ending one tile before is free")
	assert_true(_store.plant_orchard(6, 10, OrchardHiveScript.SPECIES_PEAR, DAY_ONE).ok,
		"and can be planted too")
	assert_true(_store.is_block_free(10, 6), "and so is one that ends one tile above on z")
	assert_true(_store.plant_orchard(10, 6, OrchardHiveScript.SPECIES_APPLE, DAY_ONE).ok,
		"which can also be planted")
	assert_true(_store.is_block_free(10, 14), "and one that starts one tile below on z")
	assert_true(_store.plant_orchard(10, 14, OrchardHiveScript.SPECIES_APPLE, DAY_ONE).ok,
		"which can also be planted")
	assert_false(_store.is_block_free(13, 10), "one tile of overlap is not free")
	assert_false(_store.is_block_free(10, 13), "and neither is one tile of overlap on z")
	assert_equal(_store.orchard_count(), 5, "five blocks are live")


# --- REQ-SET-079/080: maturity, the annual harvest and the harvested-year flag ---------------------

func _mature_apple_at(origin_x: int, origin_z: int) -> Vector2i:
	"""Plant an apple block and restore it to a mature, full-health, well-chilled state."""
	var ref: Vector2i = _plant_apple(origin_x, origin_z, DAY_ONE)
	assert_true(_store.restore_orchard_state(ref, 96, 10000, 6, false, false).ok,
		"the fixture block is mature")
	return ref


func test_an_immature_tree_yields_nothing_and_cannot_be_harvested() -> void:
	"""§5.6: "Immature trees yield 0", and the harvest refuses rather than paying it."""
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(ref)
	assert_false(_store.is_mature(row), "a freshly planted block is not mature")
	assert_true(_store.orchard_yield_milli_into(row, _out), "the yield reads")
	assert_equal(_out.value, 0, "and is zero")
	var refusal: OrchardHiveScript.OpResult = _store.harvest_orchard(ref, APPLE_FIRST_HARVEST_DAY)
	assert_false(refusal.ok, "an immature tree cannot be harvested")
	assert_equal(refusal.error, OrchardHiveScript.REFUSE_NOT_MATURE, "with the maturity code")


func test_a_mature_tree_pays_one_year_of_fruit_and_sets_the_harvested_flag() -> void:
	"""REQ-SET-080: the flag is set on completion and prohibits a second harvest that year."""
	var ref: Vector2i = _mature_apple_at(10, 10)
	var row: int = _row_of(ref)
	var harvest: OrchardHiveScript.OpResult = _store.harvest_orchard(ref, APPLE_FIRST_HARVEST_DAY)
	assert_true(harvest.ok, "the harvest succeeds (%s)" % harvest.error)
	assert_equal(harvest.value, 80000, "80 fruit U at full health, no hive and full chill")
	assert_true(_store.is_harvested_year(row), "the harvested-year flag is set")
	var second: OrchardHiveScript.OpResult = _store.harvest_orchard(ref, APPLE_FIRST_HARVEST_DAY + 1)
	assert_false(second.ok, "a second harvest the same year is refused")
	assert_equal(second.error, OrchardHiveScript.REFUSE_ALREADY_HARVESTED_THIS_YEAR,
		"with the once-a-year code")


func test_a_tree_left_unharvested_for_years_still_pays_one_year_of_fruit() -> void:
	"""REQ-SET-079: maturity enables the NEXT harvest and generates no previous years' fruit."""
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(ref)
	assert_true(_store.restore_orchard_state(ref, 96 + 96, 10000, 6, false, false).ok,
		"the tree has been mature for two further years")
	var harvest: OrchardHiveScript.OpResult = _store.harvest_orchard(ref, APPLE_FIRST_HARVEST_DAY + 96)
	assert_true(harvest.ok, "the harvest succeeds (%s)" % harvest.error)
	assert_equal(harvest.value, 80000, "one year's fruit, not two or three")
	assert_true(_store.is_harvested_year(row), "and the year is now spent")


func test_a_harvest_outside_the_window_is_refused() -> void:
	"""§5.6's autumn windows are inclusive and are the only legal harvest days."""
	var ref: Vector2i = _mature_apple_at(10, 10)
	var early: OrchardHiveScript.OpResult = _store.harvest_orchard(ref, APPLE_FIRST_HARVEST_DAY - 1)
	assert_false(early.ok, "the day before the window opens is refused")
	assert_equal(early.error, OrchardHiveScript.REFUSE_OUTSIDE_HARVEST_WINDOW, "with the window code")
	assert_false(_store.harvest_orchard(ref, APPLE_FIRST_HARVEST_DAY + 6).ok,
		"the day after apple's six-day window closes is refused")
	assert_true(_store.harvest_orchard(ref, APPLE_FIRST_HARVEST_DAY + 5).ok,
		"the window's last day is inclusive")


func test_the_harvested_year_flag_clears_at_the_start_of_the_next_year() -> void:
	"""The flag is cleared by spring day 1 and by nothing else, so no year is ever back-filled."""
	var ref: Vector2i = _mature_apple_at(10, 10)
	var row: int = _row_of(ref)
	assert_true(_store.harvest_orchard(ref, APPLE_FIRST_HARVEST_DAY).ok, "harvest in year 3")
	assert_true(_store.apply_orchard_day(ref, APPLE_FIRST_HARVEST_DAY + 1, MILD_TENTHS).ok,
		"an ordinary autumn day passes")
	assert_true(_store.is_harvested_year(row), "which does not clear the flag")
	assert_true(_store.apply_orchard_day(ref, 133, MILD_TENTHS).ok, "winter day 1 of year 3 arrives")
	assert_true(_store.is_harvested_year(row), "which is a season start but not a year start")
	assert_true(_store.apply_orchard_day(ref, 145, MILD_TENTHS).ok, "year 4 spring day 1 arrives")
	assert_false(_store.is_harvested_year(row), "and clears the flag")


# --- §5.6 orchard care, chill and yield arithmetic ----------------------------------------------------

func test_untended_spring_and_summer_days_remove_a_hundred_health() -> void:
	"""§5.6's untended penalty, applied in the growing season and nowhere else."""
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(ref)
	assert_true(_store.apply_orchard_day(ref, DAY_ONE, MILD_TENTHS).ok, "a spring day passes")
	assert_equal(_store.orchard_health_of(row).value, 9900, "an untended spring day removes 100")
	assert_true(_store.apply_orchard_day(ref, SUMMER_DAY_ONE, MILD_TENTHS).ok, "a summer day passes")
	assert_equal(_store.orchard_health_of(row).value, 9800, "an untended summer day removes 100")
	assert_true(_store.apply_orchard_day(ref, AUTUMN_DAY_ONE, MILD_TENTHS).ok, "an autumn day passes")
	assert_equal(_store.orchard_health_of(row).value, 9800, "autumn changes no health")
	assert_true(_store.apply_orchard_day(ref, WINTER_DAY_ONE, MILD_TENTHS).ok, "a winter day passes")
	assert_equal(_store.orchard_health_of(row).value, 9800, "and neither does winter")


func test_a_tended_day_restores_fifty_health_and_clamps_at_ten_thousand() -> void:
	"""§5.6: "tended days restore 50, max 10000", and the flag clears at the end of the day."""
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(ref)
	assert_true(_store.restore_orchard_state(ref, 0, 9000, 0, false, false).ok, "start at 9000")
	assert_equal(_store.record_tending(ref).value, 20000, "care is §5.6's 20 WU")
	assert_true(_store.is_tended_today(row), "the day is marked tended")
	assert_true(_store.apply_orchard_day(ref, DAY_ONE, MILD_TENTHS).ok, "the day completes")
	assert_equal(_store.orchard_health_of(row).value, 9050, "a tended spring day restores 50")
	assert_false(_store.is_tended_today(row), "and the flag is cleared for the next day")
	assert_true(_store.restore_orchard_state(ref, 0, 9990, 0, true, false).ok, "start just below the cap")
	assert_true(_store.apply_orchard_day(ref, DAY_ONE + 1, MILD_TENTHS).ok, "another tended day")
	assert_equal(_store.orchard_health_of(row).value, 10000, "health clamps at 10000")


func test_the_age_advances_every_day_including_winter() -> void:
	"""§5.6: "age is retained across winter", so a winter day still counts toward maturity."""
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(ref)
	assert_equal(_store.age_days_of(row).value, 0, "a new block is zero days old")
	assert_true(_store.apply_orchard_day(ref, WINTER_DAY_ONE, MILD_TENTHS).ok, "a winter day passes")
	assert_equal(_store.age_days_of(row).value, 1, "which still advances the age")
	assert_true(_store.apply_orchard_day(ref, WINTER_DAY_ONE + 1, MILD_TENTHS).ok, "and another")
	assert_equal(_store.age_days_of(row).value, 2, "age accumulates through the winter")


func test_the_chill_counter_counts_winter_days_at_or_below_five_degrees() -> void:
	"""§5.6's counter, at the stated boundary and reset on winter's own first day."""
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(ref)
	assert_true(_store.apply_orchard_day(ref, WINTER_DAY_ONE, CHILL_TENTHS).ok, "5.0 degC in winter")
	assert_equal(_store.chill_days_of(row).value, 1, "exactly 5 degC is a chill day")
	assert_true(_store.apply_orchard_day(ref, WINTER_DAY_ONE + 1, CHILL_TENTHS + 1).ok, "5.1 degC")
	assert_equal(_store.chill_days_of(row).value, 1, "one tenth above 5 degC is not")
	assert_true(_store.apply_orchard_day(ref, DAY_ONE, CHILL_TENTHS).ok, "a cold spring day")
	assert_equal(_store.chill_days_of(row).value, 1, "counts nothing outside winter")
	assert_true(_store.apply_orchard_day(ref, WINTER_DAY_ONE + 48, CHILL_TENTHS).ok,
		"the next winter's first day")
	assert_equal(_store.chill_days_of(row).value, 1, "resets the counter before counting itself")


func test_a_poorly_chilled_tree_yields_three_quarters() -> void:
	"""§5.6: "fewer than 6 chill days in the previous winter gives 75% yield"."""
	var ref: Vector2i = _mature_apple_at(10, 10)
	var row: int = _row_of(ref)
	assert_equal(_store.chill_factor_of(row).value, 100, "six chill days is a full factor")
	assert_true(_store.restore_orchard_state(ref, 96, 10000, 5, false, false).ok, "five chill days")
	assert_equal(_store.chill_factor_of(row).value, 75, "five is below the stated six")
	assert_true(_store.orchard_yield_milli_into(row, _out), "the yield reads")
	assert_equal(_out.value, 60000, "80 U at 75% is 60 U")


func test_the_orchard_yield_multiplies_health_pollination_and_chill_once() -> void:
	"""§5.6's stated multipliers, floored once: 80 U x 5000/10000 x 1150/1000 x 75/100."""
	_hive_at(11, 10)
	_hive_at(11, 11)
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(ref)
	assert_true(_store.restore_orchard_state(ref, 96, 10000, 6, false, false).ok, "full health")
	assert_true(_store.orchard_yield_milli_into(row, _out), "the yield reads")
	assert_equal(_out.value, 92000, "80 U with two healthy hives is 92 U")
	assert_true(_store.restore_orchard_state(ref, 96, 5000, 5, false, false).ok, "half health, low chill")
	assert_true(_store.orchard_yield_milli_into(row, _out), "the yield reads")
	assert_equal(_out.value, 34500, "80000*5000*1150*75/10^9 = 34500")


func test_one_hive_raises_the_orchard_yield_to_the_stated_multiplier() -> void:
	"""Orchard fruit is pollinated like beans: 1100 with one healthy hive within 12 m."""
	var hive: Vector2i = _hive_at(11, 10)
	var ref: Vector2i = _mature_apple_at(10, 10)
	var row: int = _row_of(ref)
	assert_true(_store.orchard_pollination_factor_into(row, _out), "the factor reads")
	assert_equal(_out.value, 1100, "one healthy hive gives 1100")
	assert_true(_store.orchard_yield_milli_into(row, _out), "the yield reads")
	assert_equal(_out.value, 88000, "80 U at 1100/1000 is 88 U")
	assert_true(_store.destroy_hive(hive).ok, "remove the hive, which refreshes orchard slices")
	assert_true(_store.orchard_yield_milli_into(row, _out), "the yield reads again")
	assert_equal(_out.value, 80000, "and returns to the unpollinated figure")


func test_the_orchard_block_centre_uses_the_whole_four_by_four_block() -> void:
	"""Ruling §3: "an orchard uses its 4x4 block", so its centre is a block boundary, not a tile."""
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(ref)
	var bounds: OrchardHiveScript.BlockBounds = _store.block_bounds_of(row)
	assert_true(bounds.ok, "the block bounds read")
	assert_equal(bounds.min_tile_x, 10, "the block starts at tile 10")
	assert_equal(bounds.max_tile_x, 13, "and ends at tile 13")
	assert_equal(_store.footprint_center_units(bounds.min_tile_x, bounds.max_tile_x).value, 24576,
		"whose centre is (10+13+1)*1024 = 24576")


func test_the_block_centre_is_the_distance_origin_at_the_range_boundary() -> void:
	"""A hive exactly 12 m from the BLOCK centre qualifies on either axis.

	The block at (10, 10) centres on (24576, 24576), an even multiple of 1024, so each fixture
	hive uses a two-tile footprint to land exactly 12288 units away on one axis with no offset on
	the other. A block centre computed from the wrong span moves by a whole tile and loses them.
	"""
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	var row: int = _row_of(ref)
	_wide_hive(5, 6, 11, 12)
	assert_true(_store.orchard_hive_count_into(row, _out), "the block's slice reads")
	assert_equal(_out.value, 1, "a hive exactly 12288 units away on x is linked")
	_wide_hive(11, 12, 5, 6)
	assert_true(_store.orchard_hive_count_into(row, _out), "the block's slice reads")
	assert_equal(_out.value, 2, "and so is one exactly 12288 units away on z")
	_wide_hive(4, 5, 11, 12)
	assert_true(_store.orchard_hive_count_into(row, _out), "the block's slice reads")
	assert_equal(_out.value, 2, "while one 14336 units away on x is not")
	_wide_hive(11, 12, 4, 5)
	assert_true(_store.orchard_hive_count_into(row, _out), "the block's slice reads")
	assert_equal(_out.value, 2, "and neither is one 14336 units away on z")


# --- §5.6 the hive ---------------------------------------------------------------------------------------

func test_a_new_hive_starts_at_the_stated_strength_and_footprint() -> void:
	"""§5.6: "Hive strength starts 8000, healthy>=5000", with an empty produce and feed store."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	assert_equal(_store.hive_strength_of(row).value, 8000, "strength starts at 8000")
	assert_true(_store.is_hive_healthy(row), "which is healthy")
	assert_false(_store.is_hive_abandoned(row), "and not abandoned")
	assert_equal(_store.hive_feed_milli_of(row).value, 0, "no feed is stocked")
	assert_equal(_store.hive_honey_milli_of(row).value, 0, "no honey has been produced")
	assert_equal(_store.hive_wax_milli_of(row).value, 0, "and no wax")
	assert_equal(_store.hive_serviced_day_of(row).value, DAY_ONE, "the founding day counts as serviced")
	assert_equal(_store.hive_center_x_of(row).value, 23552, "tile 11 centres at 23552")


func test_a_hive_needs_a_live_building_reference_it_never_dereferences() -> void:
	"""`Hive.building` is validated for liveness and kind; there is no Building store to read."""
	assert_false(_store.create_hive(EntityDirectoryScript.NULL_REF, 11, 10, 11, 10, DAY_ONE).ok,
		"the null reference is refused")
	var wrong_kind: Vector2i = _dir.create(EntityDirectoryScript.KIND_ROOM)
	assert_false(_store.create_hive(wrong_kind, 11, 10, 11, 10, DAY_ONE).ok,
		"a reference of another kind is refused")
	var building: Vector2i = _new_building()
	assert_true(_dir.destroy(building), "destroy the building before the hive is made")
	assert_false(_store.create_hive(building, 11, 10, 11, 10, DAY_ONE).ok,
		"a stale building reference is refused")
	var live: Vector2i = _new_building()
	var created: OrchardHiveScript.OpResult = _store.create_hive(live, 11, 10, 11, 10, DAY_ONE)
	assert_true(created.ok, "a live building reference is accepted")
	assert_equal(_store.hive_building_ref_of(_dir.get_typed_row(created.ref)), live,
		"and is stored unchanged")


func test_a_hive_footprint_must_be_an_on_grid_rectangle() -> void:
	"""Rotation is resolved before the bounds are taken; what arrives must be a valid rectangle."""
	assert_false(_store.create_hive(_new_building(), 11, 10, 10, 10, DAY_ONE).ok,
		"an inverted x span is refused")
	assert_false(_store.create_hive(_new_building(), 11, 10, 11, 128, DAY_ONE).ok,
		"a bound off the 128x128 grid is refused")
	assert_false(_store.create_hive(_new_building(), -1, 10, 11, 10, DAY_ONE).ok,
		"a negative bound is refused")
	assert_equal(_store.hive_count(), 0, "and no partly written hive is left behind")


func test_a_serviced_spring_day_produces_honey_and_wax_and_restores_strength() -> void:
	"""§5.6: honey 2 U + wax 0.25 U x strength/10000, then spring's 300 restore AFTER production."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	var day: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, DAY_ONE)
	assert_true(day.ok, "the day completes (%s)" % day.error)
	assert_true(day.serviced, "the founding day counts as serviced")
	assert_equal(day.honey_milli, 1600, "2000 x 8000/10000")
	assert_equal(day.wax_milli, 200, "250 x 8000/10000")
	assert_equal(day.strength_after, 8300, "and spring restores 300 after production")
	assert_equal(_store.hive_honey_milli_of(row).value, 1600, "the honey is stocked on the hive")
	assert_equal(_store.hive_wax_milli_of(row).value, 200, "and so is the wax")


func test_a_serviced_summer_day_produces_but_does_not_restore_strength() -> void:
	"""§5.6 restores 300 on tended SPRING days only; summer and autumn produce without it."""
	var hive: Vector2i = _hive_at(11, 10)
	assert_true(_store.record_hive_service(hive, SUMMER_DAY_ONE).ok, "service the hive in summer")
	var day: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, SUMMER_DAY_ONE)
	assert_true(day.ok, "the day completes (%s)" % day.error)
	assert_equal(day.honey_milli, 1600, "summer produces the same honey")
	assert_equal(day.strength_after, 8000, "but restores no strength")
	assert_true(_store.record_hive_service(hive, AUTUMN_DAY_ONE).ok, "service it in autumn")
	var autumn: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, AUTUMN_DAY_ONE)
	assert_equal(autumn.strength_after, 8000, "autumn restores none either")
	assert_equal(autumn.wax_milli, 200, "and still produces wax")


func test_a_missed_service_day_removes_two_hundred_strength_and_produces_nothing() -> void:
	"""§5.6's missed-service penalty in spring, summer and autumn."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	var day: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, DAY_ONE + 1)
	assert_true(day.ok, "the day completes (%s)" % day.error)
	assert_false(day.serviced, "the hive was not serviced that day")
	assert_equal(day.honey_milli, 0, "so it produced no honey")
	assert_equal(day.wax_milli, 0, "and no wax")
	assert_equal(day.strength_after, 7800, "and lost 200 strength")
	assert_equal(_store.hive_strength_of(row).value, 7800, "which is stored")


func test_a_winter_day_eats_stocked_feed_and_produces_nothing() -> void:
	"""§5.6: "Winter produces 0 and consumes honey 0.5 U/day", with no service required."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	assert_equal(_store.add_hive_feed(hive, 1000).value, 1000, "stock 1 U of honey")
	var day: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, WINTER_DAY_ONE)
	assert_true(day.ok, "the day completes (%s)" % day.error)
	assert_equal(day.feed_consumed_milli, 500, "500 milli-U is eaten")
	assert_equal(day.honey_milli, 0, "winter produces no honey")
	assert_equal(day.strength_after, 8000, "and a fed hive loses no strength")
	assert_equal(_store.hive_feed_milli_of(row).value, 500, "the remaining feed is stored")
	assert_false(_store.is_service_due(row, WINTER_DAY_ONE), "winter needs feed, not tending labor")


func test_a_missing_winter_feed_removes_five_hundred_strength_and_eats_nothing() -> void:
	"""§5.6's winter penalty. A partial stock is left alone, so the deficit stays true."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	assert_equal(_store.add_hive_feed(hive, 400).value, 400, "stock less than one day's feed")
	var day: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, WINTER_DAY_ONE)
	assert_true(day.ok, "the day completes (%s)" % day.error)
	assert_equal(day.feed_consumed_milli, 0, "an insufficient stock is not part-eaten")
	assert_equal(day.strength_after, 7500, "and the hive loses 500 strength")
	assert_equal(_store.hive_feed_milli_of(row).value, 400, "the partial stock is untouched")
	assert_true(_store.feed_deficit_milli_into(row, WINTER_DAY_ONE, _out), "the deficit reads")
	assert_equal(_out.value, 100, "and still names the 100 milli-U that is owed")


func test_exactly_one_day_of_winter_feed_is_enough() -> void:
	"""The feed test is inclusive: exactly 500 milli-U feeds the day, and 499 does not."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	assert_equal(_store.add_hive_feed(hive, 500).value, 500, "stock exactly one day's feed")
	assert_true(_store.feed_deficit_milli_into(row, WINTER_DAY_ONE, _out), "the deficit reads")
	assert_equal(_out.value, 0, "and nothing is owed")
	var fed: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, WINTER_DAY_ONE)
	assert_equal(fed.feed_consumed_milli, 500, "exactly one day's feed is eaten")
	assert_equal(fed.strength_after, 8000, "and no strength is lost")
	assert_equal(_store.add_hive_feed(hive, 499).value, 499, "stock one milli-U short")
	var unfed: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, WINTER_DAY_ONE + 1)
	assert_equal(unfed.feed_consumed_milli, 0, "one milli-U short is not enough")
	assert_equal(unfed.strength_after, 7500, "and costs the stated 500 strength")


func test_strength_is_clamped_to_the_ten_thousand_scale() -> void:
	"""The stated production denominator is the full-strength value; spring restores cannot pass it."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	assert_true(_store.restore_hive_state(hive, 9900, 0, 0, 0, DAY_ONE).ok, "start near the cap")
	var day: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, DAY_ONE)
	assert_true(day.ok, "the day completes (%s)" % day.error)
	assert_equal(day.honey_milli, 1980, "2000 x 9900/10000")
	assert_equal(_store.hive_strength_of(row).value, 10000, "and the restore clamps at 10000")
	assert_false(_store.restore_hive_state(hive, 10001, 0, 0, 0, DAY_ONE).ok,
		"a loaded strength above the scale is refused, not clamped silently")


func test_deficits_are_readable_before_the_hive_is_abandoned() -> void:
	"""REQ-SET-083: the feed and service deficits are shown BEFORE abandonment, not after it."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	assert_true(_store.restore_hive_state(hive, 200, 0, 0, 0, DAY_ONE).ok, "one bad day from zero")
	assert_true(_store.service_deficit_days_into(row, DAY_ONE + 3, _out), "the service deficit reads")
	assert_equal(_out.value, 3, "three days since the last service")
	assert_true(_store.is_service_due(row, DAY_ONE + 3), "and a service is due")
	assert_true(_store.feed_deficit_milli_into(row, WINTER_DAY_ONE, _out), "the feed deficit reads")
	assert_equal(_out.value, 500, "a whole day's feed is owed")
	assert_false(_store.is_hive_abandoned(row), "and the hive is not abandoned yet")
	var day: OrchardHiveScript.HiveDayResult = _store.apply_hive_day(hive, DAY_ONE + 3)
	assert_true(day.abandoned, "the next missed service day abandons it")
	assert_equal(day.strength_after, 0, "at exactly zero strength")


func test_an_abandoned_hive_refuses_service_and_recolonises_only_in_spring() -> void:
	"""§5.6: recolonisation is a spring operation on a hive at 0 strength, back to 8000."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	assert_true(_store.restore_hive_state(hive, 0, 0, 0, 0, DAY_ONE).ok, "abandon the hive")
	assert_true(_store.is_hive_abandoned(row), "which reads as abandoned")
	assert_false(_store.record_hive_service(hive, DAY_ONE + 1).ok, "an abandoned hive refuses service")
	assert_false(_store.recolonize_hive(hive, SUMMER_DAY_ONE).ok, "and cannot be recolonised in summer")
	var spring: OrchardHiveScript.OpResult = _store.recolonize_hive(hive, YEAR_TWO_DAY_ONE)
	assert_true(spring.ok, "but can be in spring (%s)" % spring.error)
	assert_equal(_store.hive_strength_of(row).value, 8000, "at the stated starting strength")
	assert_false(_store.recolonize_hive(hive, YEAR_TWO_DAY_ONE).ok,
		"and a live hive cannot be recolonised again")


func test_the_hive_service_and_recolonisation_figures_are_transcribed_exactly() -> void:
	"""§5.6's hive numbers, including the ones this store exposes for jobs it does not create."""
	assert_equal(OrchardHiveScript.HIVE_SERVICE_WORK_MILLI_WU, 20000, "service is 20 WU/day")
	assert_equal(OrchardHiveScript.HIVE_WINTER_FEED_MILLI_PER_DAY, 500, "winter eats honey 0.5 U/day")
	assert_equal(OrchardHiveScript.HIVE_MISSING_FEED_STRENGTH_LOSS, 500, "missing feed costs 500")
	assert_equal(OrchardHiveScript.HIVE_MISSED_SERVICE_STRENGTH_LOSS, 200, "a missed service costs 200")
	assert_equal(OrchardHiveScript.HIVE_TENDED_SPRING_STRENGTH_GAIN, 300, "a tended spring day gains 300")
	assert_equal(OrchardHiveScript.HIVE_RECOLONIZE_HONEY_MILLI, 4000, "recolonisation honey 4")
	assert_equal(OrchardHiveScript.HIVE_RECOLONIZE_WOOD_MILLI, 2000, "recolonisation wood 2")
	assert_equal(OrchardHiveScript.HIVE_RECOLONIZE_WORK_MILLI_WU, 60000, "recolonisation 60 WU")
	assert_equal(OrchardHiveScript.HIVE_RECOLONIZE_WAIT_DAYS, 3, "and a 3-day wait")


func test_collecting_honey_and_wax_empties_the_hive_store() -> void:
	"""Uncollected produce is hive stock; collection hands back a quantity and zeroes the column."""
	var hive: Vector2i = _hive_at(11, 10)
	var row: int = _dir.get_typed_row(hive)
	assert_true(_store.apply_hive_day(hive, DAY_ONE).ok, "one productive day")
	assert_equal(_store.collect_honey(hive).value, 1600, "the day's honey is collected")
	assert_equal(_store.hive_honey_milli_of(row).value, 0, "and the hive keeps none of it")
	assert_equal(_store.collect_wax(hive).value, 200, "the day's wax is collected")
	assert_equal(_store.hive_wax_milli_of(row).value, 0, "and the hive keeps none of it")
	assert_equal(_store.collect_honey(hive).value, 0, "a second collection finds nothing")


# --- ruling §3: the synchronous refresh discipline ---------------------------------------------------

func test_an_eligibility_crossing_refreshes_the_orchard_slices_synchronously() -> void:
	"""A hive falling below 5000 during its own day step updates every orchard slice at once."""
	var hive: Vector2i = _hive_at(11, 10)
	var ref: Vector2i = _mature_apple_at(10, 10)
	var row: int = _row_of(ref)
	assert_true(_store.orchard_hive_count_into(row, _out), "the block's slice reads")
	assert_equal(_out.value, 1, "the healthy hive is linked")
	assert_true(_store.restore_hive_state(hive, 5000, 0, 0, 0, DAY_ONE).ok, "drop it to the line")
	assert_true(_store.apply_hive_day(hive, DAY_ONE + 1).ok, "a missed service day takes it to 4800")
	assert_true(_store.orchard_hive_count_into(row, _out),
		"the block's slice still reads, with no explicit refresh")
	assert_equal(_out.value, 0, "because the crossing refreshed it synchronously")
	assert_true(_store.check_orchard_links(ref), "and the slice is canonical")


func test_creating_and_moving_a_hive_refreshes_every_orchard_slice() -> void:
	"""Creation, footprint change and destruction are all committed changes that refresh at once."""
	var ref: Vector2i = _mature_apple_at(10, 10)
	var row: int = _row_of(ref)
	var hive: Vector2i = _hive_at(60, 60)
	assert_true(_store.orchard_hive_count_into(row, _out), "the block's slice reads")
	assert_equal(_out.value, 0, "a distant hive is not linked")
	assert_true(_store.set_hive_footprint(hive, 11, 10, 11, 10).ok, "move the apiary next door")
	assert_true(_store.orchard_hive_count_into(row, _out), "the block's slice reads")
	assert_equal(_out.value, 1, "and the moved hive is linked without an explicit refresh")
	assert_true(_store.destroy_hive(hive).ok, "remove it again")
	assert_true(_store.orchard_hive_count_into(row, _out), "the block's slice reads")
	assert_equal(_out.value, 0, "and the destruction refreshed the slice too")


# --- ruling §3: serialization and the load-time canonical check ---------------------------------------

func test_the_link_image_round_trips_in_process() -> void:
	"""The image is written in declared owner order and restores to the same 30720 references."""
	_hive_at(11, 10)
	var ref: Vector2i = _mature_apple_at(10, 10)
	assert_true(_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z).ok, "a farm slice is written")
	var image: PackedByteArray = _store.link_state_bytes()
	_store.clear_all_links()
	assert_equal(_farm_count(FARM_ROW), 0, "the columns are empty before the restore")
	assert_true(_store.restore_links_from_state(image).ok, "the image restores")
	assert_equal(_farm_count(FARM_ROW), 1, "the farm slice is back")
	assert_true(_store.check_farm_links(FARM_ROW, CROP_X, CROP_Z), "and matches the canonical selection")
	assert_true(_store.check_orchard_links(ref), "as does the orchard slice")
	assert_equal(_store.revalidate_orchard_links_after_load().value, 0,
		"so the load recomputes nothing")


func test_a_load_recomputes_a_slice_that_disagrees_with_the_canonical_selection() -> void:
	"""Ruling §3: links are validated or recomputed on load, never silently trusted."""
	var hive: Vector2i = _hive_at(11, 10)
	var ref: Vector2i = _mature_apple_at(10, 10)
	var image: PackedByteArray = _store.link_state_bytes()
	assert_true(_store.destroy_hive(hive).ok, "the hive is gone in the world being loaded into")
	assert_true(_store.restore_links_from_state(image).ok, "the older image restores")
	assert_false(_store.is_slice_valid(_store.recipient_index_of_orchard_row(_row_of(ref)).value),
		"the restored slice names a hive that no longer exists")
	var report: OrchardHiveScript.OpResult = _store.revalidate_orchard_links_after_load()
	assert_true(report.ok, "the revalidation succeeds")
	assert_equal(report.value, 1, "and reports one recomputed slice")
	assert_true(_store.orchard_hive_count_into(_row_of(ref), _out), "after which the slice reads")
	assert_equal(_out.value, 0, "as the canonical empty selection")


func test_a_farm_slice_is_revalidated_against_its_own_tile_on_load() -> void:
	"""A FarmPlot's tile is the caller's, so its load check takes the coordinates back in."""
	var hive: Vector2i = _hive_at(11, 10)
	assert_true(_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z).ok, "the slice is written")
	assert_equal(_store.revalidate_farm_links_after_load(FARM_ROW, CROP_X, CROP_Z).value, 0,
		"a canonical slice is left alone")
	assert_true(_store.destroy_hive(hive).ok, "destroy the hive without refreshing the farm slice")
	assert_equal(_store.revalidate_farm_links_after_load(FARM_ROW, CROP_X, CROP_Z).value, 1,
		"the stale slice is recomputed")
	assert_equal(_farm_count(FARM_ROW), 0, "and now reads as empty")


func test_a_malformed_link_image_refuses_whole() -> void:
	"""A corrupt image writes nothing rather than half-loading the table."""
	_hive_at(11, 10)
	assert_true(_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z).ok, "a slice is written")
	var short_image: PackedInt32Array = PackedInt32Array()
	short_image.resize(10)
	var refusal: OrchardHiveScript.OpResult = _store.restore_links_from_state(
		var_to_bytes(short_image))
	assert_false(refusal.ok, "an image of the wrong length is refused")
	assert_equal(refusal.error, OrchardHiveScript.REFUSE_INVALID_STATE_IMAGE, "with the image code")
	assert_false(_store.restore_links_from_state(var_to_bytes("not an image")).ok,
		"and so is an image of the wrong type")
	assert_equal(_farm_count(FARM_ROW), 1, "the live slice was not disturbed")


# --- store lifecycle ---------------------------------------------------------------------------------

func test_clear_returns_every_column_and_the_directory_to_empty() -> void:
	"""A cleared store leaks no directory allocation and keeps no link from the previous world."""
	_hive_at(11, 10)
	_plant_apple(10, 10, DAY_ONE)
	_store.refresh_farm_links(FARM_ROW, CROP_X, CROP_Z)
	assert_equal(_store.hive_count(), 1, "one hive is live")
	assert_equal(_store.orchard_count(), 1, "one block is live")
	_store.clear()
	assert_equal(_store.hive_count(), 0, "no hive survives the clear")
	assert_equal(_store.orchard_count(), 0, "no block survives the clear")
	assert_equal(_farm_count(FARM_ROW), 0, "and no link survives it either")
	assert_equal(_dir.live_count(EntityDirectoryScript.KIND_HIVE), 0,
		"the hive's directory row was released")
	assert_equal(_dir.live_count(EntityDirectoryScript.KIND_ORCHARD_PLOT), 0,
		"and so was the block's")


func test_removing_a_block_returns_wood_and_frees_its_tiles() -> void:
	"""§5.6: "Orchard removal yields wood 8 and no refunded sapling"."""
	var ref: Vector2i = _plant_apple(10, 10, DAY_ONE)
	assert_false(_store.is_block_free(10, 10), "the block's tiles are taken")
	var removal: OrchardHiveScript.OpResult = _store.remove_orchard(ref)
	assert_true(removal.ok, "the removal succeeds")
	assert_equal(removal.value, 8000, "and yields wood 8")
	assert_true(_store.is_block_free(10, 10), "after which the tiles are free again")
	assert_false(_store.remove_orchard(ref).ok, "and a second removal refuses")
