extends "res://test/framework/test_case.gd"
## Coverage for the ResourceNode store and its exterior-tile placement primitive.
##
## Every fixture value below is restated from the specification, never read back out of the
## module under test: the tile indices are computed by hand from GDD §5.1's `z*128+x`, the tile
## centres from its `(2048*x+1024,0,2048*z+1024)`, the 4096 cap from §4.2, and the 48-day tree
## regrowth from §5.9. Calendar days come from `sim_clock.gd`'s own decoder at real tick
## boundaries, so the regrowth test crosses a genuine midnight rather than incrementing an int.
##
## GDD §4.2 never states what domain `resource_id` is drawn from (see the module header), so the
## ids here are opaque small integers and no test asserts a meaning for them.

const ResourceNodes := preload("res://scripts/core/resource_nodes.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## GDD §4.2: "Tree/stone/iron source; at most 4096".
const EXPECTED_CAPACITY: int = 4096

## GDD §5.1: exterior index `z*128+x`; a 128x128 grid, matching WorldTileMaps' 16384 rows.
const EXPECTED_TILE_COUNT: int = 16384

## §5.1 landmarks, indices worked out by hand from `z*128+x`.
## Grove corner (40,54): 54*128+40 = 6952. Stone origin (44,70): 70*128+44 = 9004.
## Iron origin (32,60): 60*128+32 = 7712. Exit (64,126): 126*128+64 = 16192.
const GROVE_TILE: int = 6952
const STONE_TILE: int = 9004
const IRON_TILE: int = 7712
const EXIT_TILE: int = 16192

## §5.1: "Each mature node contains 12 wood U", in milli-units.
const TREE_WOOD_MILLI: int = 12000

## §5.9: "Trees regrow after 48 days when their stumps remain".
const TREE_REGROW_DAYS: int = 48

## §5.9: surface stone deposits can exhaust, and the document states no regrowth period for
## them. Zero is the store's "never regrows" period.
const NON_RENEWABLE: int = 0

## Opaque resource ids; the GDD fixes no domain for them.
const RESOURCE_TREE: int = 0
const RESOURCE_STONE: int = 1
const RESOURCE_IRON: int = 2

const FIRST_DAY: int = 1
const INT32_MAX: int = 2147483647

## Decision 0029's table, transcribed here and not read back out of the module: stone
## `x=44..47, z=70..73`, 16 nodes, 75000 milli-U each, 1200000 total; iron `x=32..35, z=60..63`,
## 16 nodes, 18750 milli-U each, 300000 total; 32 of the 4096 rows. Tile indices below are
## computed by `_tile()` from §5.1's own `z*128+x`, never by calling the module's encoder.
const DEPOSIT_NODES: int = 16
const DEPOSIT_SIZE: int = 4
const BOTH_DEPOSITS_NODES: int = 32
const STONE_ORIGIN_X: int = 44
const STONE_ORIGIN_Z: int = 70
const STONE_NODE_MILLI: int = 75000
const STONE_TOTAL_MILLI: int = 1200000
const IRON_ORIGIN_X: int = 32
const IRON_ORIGIN_Z: int = 60
const IRON_NODE_MILLI: int = 18750
const IRON_TOTAL_MILLI: int = 300000

## §5.1's renewable bedrock access, which decision 0029 puts in neither deposit total and this
## module does not place. It is one tile east of the stone footprint's east edge (47).
const BEDROCK_ACCESS_X: int = 48
const BEDROCK_ACCESS_Z: int = 70

var _nodes: ResourceNodes = null


func before_each() -> void:
	"""Build a resource-node store owning a private entity directory."""
	_nodes = ResourceNodes.new()


func after_each() -> void:
	"""Drop the store built for the test."""
	_nodes = null


func _place_tree(tile: int, day: int) -> int:
	"""Place a full 12 U tree on `tile` and return its row, failing the test on a refusal."""
	var result: ResourceNodes.OpResult = _nodes.create_at_tile(
		tile, RESOURCE_TREE, TREE_WOOD_MILLI, TREE_REGROW_DAYS, day)
	if not result.ok:
		fail("placing a tree on tile %d refused: %s" % [tile, result.error])
		return -1
	return result.value


func _tile(x: int, z: int) -> int:
	"""GDD §5.1's exterior tile index, computed here so no assertion trusts the module's own."""
	return z * 128 + x


# --- GDD §5.1 tile geometry -----------------------------------------------------------------

func test_tile_index_is_z_times_128_plus_x() -> void:
	"""GDD §5.1's exterior index formula, on the origin, the landmarks and the last tile."""
	assert_equal(_nodes.tile_index(0, 0).value, 0, "tile (0,0)")
	assert_equal(_nodes.tile_index(40, 54).value, GROVE_TILE, "grove corner (40,54)")
	assert_equal(_nodes.tile_index(44, 70).value, STONE_TILE, "stone origin (44,70)")
	assert_equal(_nodes.tile_index(32, 60).value, IRON_TILE, "iron origin (32,60)")
	assert_equal(_nodes.tile_index(64, 126).value, EXIT_TILE, "exit (64,126)")
	assert_equal(_nodes.tile_index(127, 127).value, EXPECTED_TILE_COUNT - 1, "last tile")
	assert_equal(ResourceNodes.TILE_COUNT, EXPECTED_TILE_COUNT, "128x128 exterior grid")


func test_tile_index_refuses_a_coordinate_off_the_grid() -> void:
	"""A coordinate outside 0..127 is refused, not folded back onto the grid."""
	var wide: IntMath.IntResult = _nodes.tile_index(128, 0)
	assert_false(wide.ok, "x=128 is off the grid")
	assert_equal(wide.value, 0, "a refusal carries no usable index")
	assert_false(_nodes.tile_index(0, 128).ok, "z=128 is off the grid")
	assert_false(_nodes.tile_index(-1, 0).ok, "negative x")
	assert_false(_nodes.tile_index(0, -1).ok, "negative z")
	assert_true(_nodes.tile_index(127, 127).ok, "the corner tile is on the grid")


func test_tile_index_round_trips_through_its_decoders() -> void:
	"""Encoding (x,z) then decoding it returns the same pair for every landmark and corner."""
	var coordinates: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(127, 0), Vector2i(0, 127), Vector2i(127, 127),
		Vector2i(40, 54), Vector2i(44, 70), Vector2i(32, 60), Vector2i(64, 126),
	]
	for point: Vector2i in coordinates:
		var tile: IntMath.IntResult = _nodes.tile_index(point.x, point.y)
		assert_true(tile.ok, "tile (%d,%d) encodes" % [point.x, point.y])
		assert_equal(_nodes.tile_x_of(tile.value).value, point.x, "x of tile %d" % tile.value)
		assert_equal(_nodes.tile_z_of(tile.value).value, point.y, "z of tile %d" % tile.value)


func test_tile_centre_is_the_gdd_simulation_unit_conversion() -> void:
	"""GDD §5.1: tile centre is `(2048*x+1024, 0, 2048*z+1024)` in simulation units."""
	assert_equal(_nodes.tile_center_x_units(0).value, 1024, "centre x of tile 0")
	assert_equal(_nodes.tile_center_z_units(0).value, 1024, "centre z of tile 0")
	# Grove corner (40,54): 2048*40+1024 = 82944, 2048*54+1024 = 111616.
	assert_equal(_nodes.tile_center_x_units(GROVE_TILE).value, 82944, "centre x of (40,54)")
	assert_equal(_nodes.tile_center_z_units(GROVE_TILE).value, 111616, "centre z of (40,54)")
	# Last tile (127,127): 2048*127+1024 = 261120 on both axes.
	var last: int = EXPECTED_TILE_COUNT - 1
	assert_equal(_nodes.tile_center_x_units(last).value, 261120, "centre x of (127,127)")
	assert_equal(_nodes.tile_center_z_units(last).value, 261120, "centre z of (127,127)")
	assert_equal(ResourceNodes.TILE_CENTER_Y_UNITS, 0, "§5.1 puts the centre at y=0")


func test_tile_decoders_refuse_an_off_grid_index() -> void:
	"""Decoding an index outside 0..16383 refuses instead of returning a wrapped coordinate."""
	assert_false(_nodes.tile_x_of(EXPECTED_TILE_COUNT).ok, "x of one past the last tile")
	assert_false(_nodes.tile_z_of(EXPECTED_TILE_COUNT).ok, "z of one past the last tile")
	assert_false(_nodes.tile_x_of(-1).ok, "x of a negative index")
	assert_false(_nodes.tile_center_x_units(EXPECTED_TILE_COUNT).ok, "centre x, off grid")
	assert_false(_nodes.tile_center_z_units(-1).ok, "centre z, off grid")
	assert_false(_nodes.is_tile_index(EXPECTED_TILE_COUNT), "16384 is not a tile")
	assert_true(_nodes.is_tile_index(EXPECTED_TILE_COUNT - 1), "16383 is a tile")


# --- placement ---------------------------------------------------------------------------------

func test_a_placed_node_carries_every_gdd_4_2_field() -> void:
	"""The §4.2 row is written whole: id, quantity, capacity, regrow period, day, exhausted."""
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	assert_true(_nodes.is_present(slot), "the row is live")
	assert_equal(_nodes.resource_id_of(slot).value, RESOURCE_TREE, "resource_id")
	assert_equal(_nodes.quantity_milli_of(slot).value, TREE_WOOD_MILLI, "quantity_milli")
	assert_equal(_nodes.capacity_milli_of(slot).value, TREE_WOOD_MILLI, "capacity_milli")
	assert_equal(_nodes.regrow_days_of(slot).value, TREE_REGROW_DAYS, "regrow_days")
	assert_equal(_nodes.planted_day_of(slot).value, FIRST_DAY, "planted_day")
	assert_false(_nodes.is_exhausted(slot), "a fresh node is not exhausted")
	assert_equal(_nodes.tile_of(slot).value, GROVE_TILE, "the row remembers its tile")
	assert_equal(_nodes.count(), 1, "one live node")


func test_tile_lookup_finds_the_node_and_leaves_every_other_tile_empty() -> void:
	"""The resource_slot column answers for the placed tile alone."""
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	assert_true(_nodes.has_node_at_tile(GROVE_TILE), "the placed tile is occupied")
	assert_equal(_nodes.slot_at_tile(GROVE_TILE).value, slot, "the tile names the row")
	assert_equal(_nodes.ref_at_tile(GROVE_TILE), _nodes.ref_of(slot), "the tile names the ref")
	assert_false(_nodes.has_node_at_tile(GROVE_TILE + 1), "the next tile is empty")
	assert_false(_nodes.has_node_at_tile(GROVE_TILE - 1), "the previous tile is empty")
	assert_false(_nodes.has_node_at_tile(STONE_TILE), "an unrelated tile is empty")
	var empty: IntMath.IntResult = _nodes.slot_at_tile(STONE_TILE)
	assert_false(empty.ok, "an empty tile refuses")
	assert_equal(empty.error, "TILE_EMPTY", "with the empty-tile code")
	assert_equal(_nodes.ref_at_tile(STONE_TILE), EntityDirectory.NULL_REF, "null ref, no node")


func test_a_second_node_on_one_tile_is_refused_not_overwritten() -> void:
	"""One tile holds at most one node, and the refusal allocates nothing at all."""
	var first: int = _place_tree(GROVE_TILE, FIRST_DAY)
	var second: ResourceNodes.OpResult = _nodes.create_at_tile(
		GROVE_TILE, RESOURCE_STONE, 1200000, NON_RENEWABLE, FIRST_DAY)
	assert_false(second.ok, "the second placement is refused")
	assert_equal(second.error, "TILE_OCCUPIED", "with the occupied-tile code")
	assert_equal(second.ref, EntityDirectory.NULL_REF, "a refusal carries no reference")
	assert_equal(_nodes.slot_at_tile(GROVE_TILE).value, first, "the first node still stands")
	assert_equal(_nodes.resource_id_of(first).value, RESOURCE_TREE, "unchanged resource id")
	assert_equal(_nodes.count(), 1, "no second row was created")
	assert_equal(_nodes.directory().live_count(EntityDirectory.KIND_RESOURCE_NODE), 1,
		"the refused create leaked no directory slot")


func test_destroying_a_node_frees_its_tile_for_a_replacement() -> void:
	"""§5.1's "Ore footprints replace tree nodes" is destroy-then-create, never a silent write."""
	var tree: int = _place_tree(IRON_TILE, FIRST_DAY)
	var tree_ref: Vector2i = _nodes.ref_of(tree)
	var removed: ResourceNodes.OpResult = _nodes.destroy(tree_ref)
	assert_true(removed.ok, "the tree is removed")
	assert_equal(removed.value, IRON_TILE, "destroy reports the freed tile")
	assert_false(_nodes.has_node_at_tile(IRON_TILE), "the tile is free again")
	assert_equal(_nodes.count(), 0, "no live node remains")
	var ore: ResourceNodes.OpResult = _nodes.create_at_tile(
		IRON_TILE, RESOURCE_IRON, 300000, NON_RENEWABLE, FIRST_DAY)
	assert_true(ore.ok, "the ore node takes the freed tile")
	assert_equal(_nodes.slot_at_tile(IRON_TILE).value, ore.value, "the tile names the ore row")
	assert_equal(_nodes.resource_id_of(ore.value).value, RESOURCE_IRON, "it is the ore node")


func test_create_refuses_every_unstorable_argument_without_allocating() -> void:
	"""Off-grid tiles, negative ids, empty capacities, negative periods and day 0 are refused."""
	var cases: Array[Array] = [
		[EXPECTED_TILE_COUNT, RESOURCE_TREE, TREE_WOOD_MILLI, TREE_REGROW_DAYS, FIRST_DAY,
			"INVALID_TILE"],
		[GROVE_TILE, -1, TREE_WOOD_MILLI, TREE_REGROW_DAYS, FIRST_DAY, "INVALID_RESOURCE_ID"],
		[GROVE_TILE, RESOURCE_TREE, 0, TREE_REGROW_DAYS, FIRST_DAY, "INVALID_CAPACITY"],
		[GROVE_TILE, RESOURCE_TREE, -1, TREE_REGROW_DAYS, FIRST_DAY, "INVALID_CAPACITY"],
		[GROVE_TILE, RESOURCE_TREE, TREE_WOOD_MILLI, -1, FIRST_DAY, "INVALID_REGROW_DAYS"],
		[GROVE_TILE, RESOURCE_TREE, TREE_WOOD_MILLI, TREE_REGROW_DAYS, 0, "INVALID_DAY"],
	]
	for case: Array in cases:
		var result: ResourceNodes.OpResult = _nodes.create_at_tile(
			case[0], case[1], case[2], case[3], case[4])
		assert_false(result.ok, "refused: %s" % case[5])
		assert_equal(result.error, case[5], "refusal code for %s" % case[5])
	assert_equal(_nodes.count(), 0, "no refused create left a row behind")
	assert_equal(_nodes.directory().live_count(EntityDirectory.KIND_RESOURCE_NODE), 0,
		"no refused create leaked a directory slot")


func test_capacity_refuses_the_four_thousand_ninety_seventh_node() -> void:
	"""GDD §4.2 caps ResourceNode at 4096; the next placement is refused, not squeezed in."""
	assert_equal(ResourceNodes.RESOURCE_NODE_CAPACITY, EXPECTED_CAPACITY, "§4.2 capacity")
	var refusals: int = 0
	for tile: int in EXPECTED_CAPACITY:
		var result: ResourceNodes.OpResult = _nodes.create_at_tile(
			tile, RESOURCE_TREE, TREE_WOOD_MILLI, TREE_REGROW_DAYS, FIRST_DAY)
		if not result.ok:
			refusals += 1
	assert_equal(refusals, 0, "the first 4096 placements all succeed")
	assert_equal(_nodes.count(), EXPECTED_CAPACITY, "4096 live nodes")
	var overflow: ResourceNodes.OpResult = _nodes.create_at_tile(
		EXPECTED_CAPACITY, RESOURCE_TREE, TREE_WOOD_MILLI, TREE_REGROW_DAYS, FIRST_DAY)
	assert_false(overflow.ok, "the 4097th node is refused")
	assert_equal(overflow.error, "CAPACITY_RESOURCE_NODE", "with the directory's §ARCH-ID-004 code")
	assert_false(_nodes.has_node_at_tile(EXPECTED_CAPACITY), "its tile stayed empty")
	assert_equal(_nodes.count(), EXPECTED_CAPACITY, "still exactly 4096 live nodes")


func test_the_live_list_stays_ascending_across_a_removal() -> void:
	"""A daily sweep iterates live rows in ascending slot order, gap-free after a destroy."""
	var first: int = _place_tree(GROVE_TILE, FIRST_DAY)
	var second: int = _place_tree(STONE_TILE, FIRST_DAY)
	var third: int = _place_tree(IRON_TILE, FIRST_DAY)
	assert_equal(_nodes.count(), 3, "three live nodes")
	assert_true(_nodes.destroy(_nodes.ref_of(second)).ok, "the middle node is destroyed")
	assert_equal(_nodes.count(), 2, "two live nodes remain")
	assert_equal(_nodes.live_slot_at(0).value, first, "first live row")
	assert_equal(_nodes.live_slot_at(1).value, third, "second live row")
	assert_false(_nodes.live_slot_at(2).ok, "there is no third live row")
	assert_false(_nodes.live_slot_at(-1).ok, "a negative index is refused")


# --- harvest, exhaustion, and stale references -------------------------------------------------

func test_harvest_cannot_take_more_than_the_node_holds() -> void:
	"""An over-draw refuses rather than clamping, and leaves the stock untouched."""
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	var over: ResourceNodes.OpResult = _nodes.harvest(slot, TREE_WOOD_MILLI + 1, FIRST_DAY)
	assert_false(over.ok, "over-drawing is refused")
	assert_equal(over.error, "INSUFFICIENT_QUANTITY", "with the insufficient-stock code")
	assert_equal(over.value, 0, "a refusal carries no quantity")
	assert_equal(_nodes.quantity_milli_of(slot).value, TREE_WOOD_MILLI, "stock is untouched")
	assert_false(_nodes.is_exhausted(slot), "a refused harvest did not exhaust the node")
	var exact: ResourceNodes.OpResult = _nodes.harvest(slot, TREE_WOOD_MILLI, FIRST_DAY)
	assert_true(exact.ok, "drawing exactly the stock succeeds")
	assert_equal(exact.value, 0, "nothing remains")


func test_partial_harvests_debit_exactly_what_was_asked() -> void:
	"""Each debit removes its own amount and no more; the remainder is reported each time."""
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	var first: ResourceNodes.OpResult = _nodes.harvest(slot, 4000, FIRST_DAY)
	assert_true(first.ok, "first debit")
	assert_equal(first.value, 8000, "12000 - 4000")
	assert_equal(_nodes.quantity_milli_of(slot).value, 8000, "stock after the first debit")
	var second: ResourceNodes.OpResult = _nodes.harvest(slot, 7999, FIRST_DAY)
	assert_true(second.ok, "second debit")
	assert_equal(second.value, 1, "8000 - 7999")
	assert_false(_nodes.is_exhausted(slot), "1 milli-unit left is not exhausted")
	assert_equal(_nodes.capacity_milli_of(slot).value, TREE_WOOD_MILLI, "capacity never moves")


func test_harvest_refuses_a_non_positive_amount_and_a_day_before_day_one() -> void:
	"""A zero or negative draw and a calendar day below 1 are refused with their own codes."""
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	var zero: ResourceNodes.OpResult = _nodes.harvest(slot, 0, FIRST_DAY)
	assert_false(zero.ok, "a zero draw is refused")
	assert_equal(zero.error, "INVALID_AMOUNT", "with the amount code")
	var negative: ResourceNodes.OpResult = _nodes.harvest(slot, -1000, FIRST_DAY)
	assert_false(negative.ok, "a negative draw is refused")
	assert_equal(negative.error, "INVALID_AMOUNT", "a negative draw cannot credit the node")
	var day_zero: ResourceNodes.OpResult = _nodes.harvest(slot, 1000, 0)
	assert_false(day_zero.ok, "day 0 is refused")
	assert_equal(day_zero.error, "INVALID_DAY", "GDD §5.1 starts the calendar at day 1")
	assert_equal(_nodes.quantity_milli_of(slot).value, TREE_WOOD_MILLI, "stock is untouched")


func test_felling_debits_once_and_dates_the_stump() -> void:
	"""REQ-SET-138 and BAL-SAFE-012: one debit, a dated stump, and no repeat."""
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	var felled: ResourceNodes.OpResult = _nodes.harvest_all(slot, 7)
	assert_true(felled.ok, "the tree is felled")
	assert_equal(felled.value, TREE_WOOD_MILLI, "the whole 12 U is debited once")
	assert_true(_nodes.is_exhausted(slot), "the node is exhausted")
	assert_equal(_nodes.quantity_milli_of(slot).value, 0, "nothing is left standing")
	assert_equal(_nodes.planted_day_of(slot).value, 7, "the stump is dated with the fell day")
	var repeat: ResourceNodes.OpResult = _nodes.harvest_all(slot, 7)
	assert_false(repeat.ok, "a second felling is refused")
	assert_equal(repeat.error, "NODE_EXHAUSTED", "with the exhausted code")
	var scrape: ResourceNodes.OpResult = _nodes.harvest(slot, 1, 7)
	assert_false(scrape.ok, "an exhausted node yields nothing more")
	assert_equal(scrape.error, "NODE_EXHAUSTED", "even for a single milli-unit")


func test_a_reference_to_a_destroyed_node_is_refused_after_its_slot_is_reused() -> void:
	"""Generation validation, not slot identity, decides whether a reference is still good."""
	var first: int = _place_tree(GROVE_TILE, FIRST_DAY)
	var stale: Vector2i = _nodes.ref_of(first)
	assert_true(_nodes.destroy(stale).ok, "the first node is destroyed")
	var reused: ResourceNodes.OpResult = _nodes.create_at_tile(
		STONE_TILE, RESOURCE_STONE, 1200000, NON_RENEWABLE, FIRST_DAY)
	assert_true(reused.ok, "a second node is placed")
	assert_equal(reused.ref.x, stale.x, "it reuses the freed directory slot")
	assert_true(reused.ref.y != stale.y, "with a new generation")
	var repeat: ResourceNodes.OpResult = _nodes.destroy(stale)
	assert_false(repeat.ok, "the stale reference is refused")
	assert_equal(repeat.error, "RESOURCE_NODE_NOT_PRESENT", "with the not-present code")
	assert_true(_nodes.has_node_at_tile(STONE_TILE), "the live node still stands on its tile")
	assert_equal(_nodes.count(), 1, "and is still counted")


func test_a_reference_of_another_kind_cannot_destroy_a_node() -> void:
	"""Kind validation, not the typed row number, decides which store a reference belongs to.

	Row numbers are per-kind, so a resident and a resource node both own row 0 in a shared
	directory. Resolving the row without checking the kind would let one destroy the other.
	"""
	var directory: EntityDirectory = EntityDirectory.new()
	var shared: ResourceNodes = ResourceNodes.new(directory)
	var placed: ResourceNodes.OpResult = shared.create_at_tile(
		GROVE_TILE, RESOURCE_TREE, TREE_WOOD_MILLI, TREE_REGROW_DAYS, FIRST_DAY)
	assert_true(placed.ok, "the node is placed")
	assert_equal(placed.value, 0, "it takes row 0 of the resource-node arena")
	var resident: Vector2i = directory.create(EntityDirectory.KIND_RESIDENT)
	assert_equal(directory.get_typed_row(resident), 0, "the resident takes row 0 of its own arena")
	var wrong: ResourceNodes.OpResult = shared.destroy(resident)
	assert_false(wrong.ok, "a resident reference cannot destroy a resource node")
	assert_equal(wrong.error, "RESOURCE_NODE_NOT_PRESENT", "with the not-present code")
	assert_true(shared.has_node_at_tile(GROVE_TILE), "the node still stands on its tile")
	assert_equal(shared.count(), 1, "and is still counted")
	assert_true(directory.is_valid(resident), "the resident row was not released either")


func test_readers_refuse_a_row_that_holds_no_node() -> void:
	"""Every reader refuses an empty row instead of handing back a zeroed default."""
	var empty: int = 0
	assert_false(_nodes.is_present(empty), "row 0 holds nothing")
	assert_false(_nodes.quantity_milli_of(empty).ok, "quantity refuses")
	assert_false(_nodes.capacity_milli_of(empty).ok, "capacity refuses")
	assert_false(_nodes.resource_id_of(empty).ok, "resource id refuses")
	assert_false(_nodes.regrow_days_of(empty).ok, "regrow days refuses")
	assert_false(_nodes.planted_day_of(empty).ok, "planted day refuses")
	assert_false(_nodes.tile_of(empty).ok, "tile refuses")
	assert_false(_nodes.is_exhausted(empty), "an empty row is not an exhausted node")
	assert_equal(_nodes.ref_of(empty), EntityDirectory.NULL_REF, "no reference to hand back")
	assert_false(_nodes.harvest(empty, 1000, FIRST_DAY).ok, "harvesting nothing refuses")
	assert_false(_nodes.quantity_milli_of(ResourceNodes.RESOURCE_NODE_CAPACITY).ok,
		"a row past the capacity refuses")


# --- regrowth across real calendar days ---------------------------------------------------------

func test_regrowth_completes_on_the_stated_calendar_day_and_not_before() -> void:
	"""A tree felled on day 1 returns on day 49, at the real tick the calendar turns over."""
	var fell_day: int = SimClock.Calendar.new(SimClock.FIRST_MIDNIGHT_TICK - 1).absolute_day
	assert_equal(fell_day, 1, "one tick before the first midnight is still day 1")
	var slot: int = _place_tree(GROVE_TILE, fell_day)
	assert_true(_nodes.harvest_all(slot, fell_day).ok, "the tree is felled on day 1")
	assert_equal(_nodes.regrow_ready_day_of(slot).value, 49, "1 + 48 days")
	# Day 49 starts at tick 48*18000 - 4500 = 859500 on the §5.1 offset calendar.
	var eve: int = SimClock.Calendar.new(859499).absolute_day
	var dawn: int = SimClock.Calendar.new(859500).absolute_day
	assert_equal(eve, 48, "tick 859499 is day 48")
	assert_equal(dawn, 49, "tick 859500 is day 49")
	assert_equal(_nodes.is_regrow_ready(slot, eve).value, 0, "not ready on day 48")
	var early: ResourceNodes.OpResult = _nodes.regrow(slot, eve)
	assert_false(early.ok, "regrowth on day 48 is refused")
	assert_equal(early.error, "REGROW_NOT_DUE", "with the not-due code")
	assert_equal(_nodes.quantity_milli_of(slot).value, 0, "the stump is still bare")
	assert_equal(_nodes.is_regrow_ready(slot, dawn).value, 1, "ready on day 49")
	var grown: ResourceNodes.OpResult = _nodes.regrow(slot, dawn)
	assert_true(grown.ok, "the tree regrows on day 49")
	assert_equal(grown.value, TREE_WOOD_MILLI, "back to its full 12 U")
	assert_equal(_nodes.quantity_milli_of(slot).value, TREE_WOOD_MILLI, "stock restored")
	assert_false(_nodes.is_exhausted(slot), "no longer a stump")


func test_a_regrown_node_can_be_felled_again_and_dated_anew() -> void:
	"""The cycle repeats: the second felling replaces the stump date with its own day."""
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	assert_true(_nodes.harvest_all(slot, 10).ok, "felled on day 10")
	assert_equal(_nodes.regrow_ready_day_of(slot).value, 58, "10 + 48 days")
	assert_true(_nodes.regrow(slot, 58).ok, "regrown on day 58")
	assert_true(_nodes.harvest_all(slot, 60).ok, "felled again on day 60")
	assert_equal(_nodes.planted_day_of(slot).value, 60, "the stump carries the new date")
	assert_equal(_nodes.regrow_ready_day_of(slot).value, 108, "60 + 48 days")
	assert_equal(_nodes.is_regrow_ready(slot, 107).value, 0, "not ready on day 107")
	assert_equal(_nodes.is_regrow_ready(slot, 108).value, 1, "ready on day 108")


func test_a_node_with_no_regrow_period_never_returns() -> void:
	"""A zero regrowth period means never; an exhausted quarry does not refill the same day."""
	var placed: ResourceNodes.OpResult = _nodes.create_at_tile(
		STONE_TILE, RESOURCE_STONE, 1200000, NON_RENEWABLE, FIRST_DAY)
	assert_true(placed.ok, "the stone deposit is placed")
	var slot: int = placed.value
	assert_true(_nodes.harvest_all(slot, FIRST_DAY).ok, "the deposit is worked out")
	assert_true(_nodes.is_exhausted(slot), "it is exhausted")
	var ready: IntMath.IntResult = _nodes.is_regrow_ready(slot, FIRST_DAY)
	assert_false(ready.ok, "readiness refuses for a non-renewable node")
	assert_equal(ready.error, "NOT_RENEWABLE", "with the non-renewable code")
	var far_future: ResourceNodes.OpResult = _nodes.regrow(slot, 100000)
	assert_false(far_future.ok, "it never regrows, however long the wait")
	assert_equal(far_future.error, "NOT_RENEWABLE", "with the non-renewable code")
	assert_equal(_nodes.quantity_milli_of(slot).value, 0, "the deposit stays empty")


func test_regrowth_refuses_a_node_that_is_not_exhausted() -> void:
	"""A standing tree has no pending cycle, so it cannot be topped back up to capacity."""
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	assert_true(_nodes.harvest(slot, 4000, FIRST_DAY).ok, "part of the stock is taken")
	var ready: IntMath.IntResult = _nodes.is_regrow_ready(slot, 100)
	assert_false(ready.ok, "readiness refuses a standing tree")
	assert_equal(ready.error, "NODE_NOT_EXHAUSTED", "with the not-exhausted code")
	var topped: ResourceNodes.OpResult = _nodes.regrow(slot, 100)
	assert_false(topped.ok, "regrowth is refused")
	assert_equal(topped.error, "NODE_NOT_EXHAUSTED", "with the not-exhausted code")
	assert_equal(_nodes.quantity_milli_of(slot).value, 8000, "the partial stock is unchanged")


func test_regrowth_refuses_an_int32_overflow_of_the_maturity_date() -> void:
	"""`planted_day + regrow_days` past int32 refuses; it never wraps to a date in the past."""
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	assert_true(_nodes.harvest_all(slot, INT32_MAX).ok, "felled on the last storable day")
	assert_equal(_nodes.planted_day_of(slot).value, INT32_MAX, "the stump carries that day")
	var ready_day: IntMath.IntResult = _nodes.regrow_ready_day_of(slot)
	assert_false(ready_day.ok, "the maturity date does not fit in int32")
	assert_equal(ready_day.error, "OVERFLOW", "with the overflow code")
	assert_equal(ready_day.value, 0, "a refusal carries no date")
	var ready: IntMath.IntResult = _nodes.is_regrow_ready(slot, INT32_MAX)
	assert_false(ready.ok, "readiness refuses too")
	var grown: ResourceNodes.OpResult = _nodes.regrow(slot, INT32_MAX)
	assert_false(grown.ok, "and the node does not regrow")
	assert_equal(_nodes.quantity_milli_of(slot).value, 0, "its stock stays at zero")


func test_the_into_forms_write_the_same_answers_without_a_new_result() -> void:
	"""The non-allocating forms match their allocating wrappers and reuse one caller result."""
	var scratch: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_nodes.tile_index_into(40, 54, scratch), "tile index into")
	assert_equal(scratch.value, GROVE_TILE, "same index as tile_index()")
	var slot: int = _place_tree(GROVE_TILE, FIRST_DAY)
	assert_true(_nodes.quantity_milli_into(slot, scratch), "quantity into")
	assert_equal(scratch.value, TREE_WOOD_MILLI, "same stock as quantity_milli_of()")
	assert_true(_nodes.harvest_into(slot, 5000, FIRST_DAY, scratch), "harvest into")
	assert_equal(scratch.value, 7000, "12000 - 5000 remaining")
	assert_false(_nodes.harvest_into(slot, 7001, FIRST_DAY, scratch), "over-draw refuses")
	assert_equal(scratch.error, "INSUFFICIENT_QUANTITY", "the refusal reaches the same result")
	assert_true(_nodes.harvest_into(slot, 7000, 12, scratch), "the node is emptied")
	assert_true(_nodes.regrow_ready_day_into(slot, scratch), "ready day into")
	assert_equal(scratch.value, 60, "12 + 48 days")
	assert_true(_nodes.is_regrow_ready_into(slot, 60, scratch), "readiness into")
	assert_equal(scratch.value, 1, "ready on day 60")


# --- store lifecycle -----------------------------------------------------------------------------

func test_clear_empties_every_row_and_every_tile() -> void:
	"""A cleared store keeps its allocation but holds no node and no tile occupancy."""
	var first: int = _place_tree(GROVE_TILE, FIRST_DAY)
	var second: int = _place_tree(STONE_TILE, FIRST_DAY)
	assert_equal(_nodes.count(), 2, "two live nodes before the clear")
	_nodes.clear()
	assert_equal(_nodes.count(), 0, "no live node after the clear")
	assert_false(_nodes.has_node_at_tile(GROVE_TILE), "the first tile is free")
	assert_false(_nodes.has_node_at_tile(STONE_TILE), "the second tile is free")
	assert_false(_nodes.is_present(first), "the first row is empty")
	assert_false(_nodes.is_present(second), "the second row is empty")
	assert_equal(_nodes.directory().live_count(EntityDirectory.KIND_RESOURCE_NODE), 0,
		"the private directory was cleared with it")
	assert_true(_nodes.create_at_tile(
		GROVE_TILE, RESOURCE_TREE, TREE_WOOD_MILLI, TREE_REGROW_DAYS, FIRST_DAY).ok,
		"the tile can be used again")


func test_a_shared_directory_is_not_cleared_by_this_store() -> void:
	"""A directory passed in belongs to its owner: clearing the node store leaves it alone."""
	var directory: EntityDirectory = EntityDirectory.new()
	var shared: ResourceNodes = ResourceNodes.new(directory)
	assert_true(shared.directory() == directory, "the store adopted the directory")
	var resident: Vector2i = directory.create(EntityDirectory.KIND_RESIDENT)
	assert_true(directory.is_valid(resident), "an unrelated resident row exists")
	assert_true(shared.create_at_tile(
		GROVE_TILE, RESOURCE_TREE, TREE_WOOD_MILLI, TREE_REGROW_DAYS, FIRST_DAY).ok,
		"a node is placed through the shared directory")
	shared.clear()
	assert_equal(shared.count(), 0, "the node store is empty")
	assert_equal(directory.live_count(EntityDirectory.KIND_RESOURCE_NODE), 0,
		"and its rows were released rather than stranded in a directory it does not own")
	assert_true(directory.is_valid(resident), "the resident reference still validates")
	assert_equal(directory.live_count(EntityDirectory.KIND_RESIDENT), 1, "and is still counted")


# --- the guaranteed 4x4 ore deposits (GDD §5.1, decision 0029) ----------------------------------

func _ore_node_quantity(x: int, z: int, resource_id: int, per_node_milli: int) -> int:
	"""Assert one footprint tile carries a full ore node, and return the stock it actually holds."""
	var tile: int = _tile(x, z)
	assert_true(_nodes.has_node_at_tile(tile), "(%d,%d) carries a deposit node" % [x, z])
	var slot: int = _nodes.slot_at_tile(tile).value
	assert_equal(_nodes.resource_id_of(slot).value, resource_id, "(%d,%d) is ore" % [x, z])
	assert_equal(_nodes.capacity_milli_of(slot).value, per_node_milli,
		"(%d,%d) capacity equals its initial quantity" % [x, z])
	assert_false(_nodes.is_exhausted(slot), "(%d,%d) starts full, not exhausted" % [x, z])
	assert_equal(_nodes.tile_of(slot).value, tile, "(%d,%d) remembers its own tile" % [x, z])
	return _nodes.quantity_milli_of(slot).value


func _footprint_tile(origin_x: int, origin_z: int, index: int) -> int:
	"""The `index`-th tile of a 4x4 footprint in ascending tile-index order (z outer, x inner)."""
	return _tile(origin_x + index % DEPOSIT_SIZE, origin_z + index / DEPOSIT_SIZE)


func _fill_trees(count: int) -> int:
	"""Place `count` trees on tiles 0..count-1, well clear of both footprints; last row placed."""
	var last: int = -1
	for tile: int in count:
		last = _place_tree(tile, FIRST_DAY)
	return last


func test_the_module_constants_transcribe_decision_0029() -> void:
	"""Every deposit constant matches the ruling's table, and each per-node quantity sums right."""
	assert_equal(ResourceNodes.DEPOSIT_FOOTPRINT_SIZE, DEPOSIT_SIZE, "a 4x4 footprint")
	assert_equal(ResourceNodes.DEPOSIT_NODE_COUNT, DEPOSIT_NODES, "sixteen nodes per deposit")
	assert_equal(ResourceNodes.STONE_DEPOSIT_ORIGIN_X, STONE_ORIGIN_X, "stone origin x is 44")
	assert_equal(ResourceNodes.STONE_DEPOSIT_ORIGIN_Z, STONE_ORIGIN_Z, "stone origin z is 70")
	assert_equal(ResourceNodes.STONE_DEPOSIT_NODE_MILLI, STONE_NODE_MILLI, "75000 milli-U each")
	assert_equal(ResourceNodes.STONE_DEPOSIT_TOTAL_MILLI, STONE_TOTAL_MILLI, "1200000 in total")
	assert_equal(ResourceNodes.IRON_DEPOSIT_ORIGIN_X, IRON_ORIGIN_X, "iron origin x is 32")
	assert_equal(ResourceNodes.IRON_DEPOSIT_ORIGIN_Z, IRON_ORIGIN_Z, "iron origin z is 60")
	assert_equal(ResourceNodes.IRON_DEPOSIT_NODE_MILLI, IRON_NODE_MILLI, "18750 milli-U each")
	assert_equal(ResourceNodes.IRON_DEPOSIT_TOTAL_MILLI, IRON_TOTAL_MILLI, "300000 in total")
	assert_equal(ResourceNodes.STONE_DEPOSIT_NODE_MILLI * DEPOSIT_NODES, STONE_TOTAL_MILLI,
		"75000 * 16 = 1200000, §5.1's 1200 U")
	assert_equal(ResourceNodes.IRON_DEPOSIT_NODE_MILLI * DEPOSIT_NODES, IRON_TOTAL_MILLI,
		"18750 * 16 = 300000, §5.1's 300 U")
	assert_equal(DEPOSIT_SIZE * DEPOSIT_SIZE, DEPOSIT_NODES, "4x4 is sixteen tiles")


func test_the_stone_deposit_is_sixteen_full_nodes_on_its_stated_tiles() -> void:
	"""Decision 0029's stone row: `x=44..47, z=70..73`, 16 nodes, 75000 milli-U each."""
	var placed: ResourceNodes.OpResult = _nodes.place_stone_deposit(
		RESOURCE_STONE, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE)
	assert_true(placed.ok, "the stone deposit is placed")
	assert_equal(placed.value, DEPOSIT_NODES, "it reports sixteen nodes")
	assert_equal(_nodes.count(), DEPOSIT_NODES, "sixteen live rows")
	var total: int = 0
	for z: int in [70, 71, 72, 73]:
		for x: int in [44, 45, 46, 47]:
			total += _ore_node_quantity(x, z, RESOURCE_STONE, STONE_NODE_MILLI)
			assert_equal(_nodes.quantity_milli_of(_nodes.slot_at_tile(_tile(x, z)).value).value,
				STONE_NODE_MILLI, "(%d,%d) holds 75000 milli-U" % [x, z])
	assert_equal(total, STONE_TOTAL_MILLI, "the sixteen nodes sum to §5.1's 1200 U")


func test_the_iron_deposit_is_sixteen_full_nodes_on_its_stated_tiles() -> void:
	"""Decision 0029's iron row: `x=32..35, z=60..63`, 16 nodes, 18750 milli-U each."""
	var placed: ResourceNodes.OpResult = _nodes.place_iron_deposit(
		RESOURCE_IRON, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE)
	assert_true(placed.ok, "the iron deposit is placed")
	assert_equal(placed.value, DEPOSIT_NODES, "it reports sixteen nodes")
	assert_equal(_nodes.count(), DEPOSIT_NODES, "sixteen live rows")
	var total: int = 0
	for z: int in [60, 61, 62, 63]:
		for x: int in [32, 33, 34, 35]:
			total += _ore_node_quantity(x, z, RESOURCE_IRON, IRON_NODE_MILLI)
			assert_equal(_nodes.quantity_milli_of(_nodes.slot_at_tile(_tile(x, z)).value).value,
				IRON_NODE_MILLI, "(%d,%d) holds 18750 milli-U" % [x, z])
	assert_equal(total, IRON_TOTAL_MILLI, "the sixteen nodes sum to §5.1's 300 U")


func test_a_deposit_touches_no_tile_outside_its_own_footprint() -> void:
	"""The block stops at origin+3 on both axes; the bedrock access tile (48,70) stays empty."""
	assert_true(_nodes.place_stone_deposit(
		RESOURCE_STONE, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE).ok, "the deposit is placed")
	assert_false(_nodes.has_node_at_tile(_tile(43, 70)), "one tile west of the footprint")
	assert_false(_nodes.has_node_at_tile(_tile(48, 73)), "one tile east of the footprint")
	assert_false(_nodes.has_node_at_tile(_tile(44, 69)), "one tile north of the footprint")
	assert_false(_nodes.has_node_at_tile(_tile(47, 74)), "one tile south of the footprint")
	assert_false(_nodes.has_node_at_tile(_tile(BEDROCK_ACCESS_X, BEDROCK_ACCESS_Z)),
		"§5.1's renewable bedrock access at (48,70) is not placed by the deposit")
	var occupied: int = 0
	for z: int in range(68, 76):
		for x: int in range(42, 50):
			if _nodes.has_node_at_tile(_tile(x, z)):
				occupied += 1
	assert_equal(occupied, DEPOSIT_NODES, "exactly sixteen tiles of the 8x8 ring are occupied")


func test_deposit_nodes_are_created_in_ascending_tile_index_order() -> void:
	"""R05-DEPOSIT-001, read through the directory's monotonic persistent ids.

	A persistent id is issued once per create and never reused, so ids rising with the tile index
	are direct evidence of the creation order. On a fresh store the typed rows rise with them,
	because the directory always hands out its lowest free row.
	"""
	assert_true(_nodes.place_stone_deposit(
		RESOURCE_STONE, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE).ok, "the deposit is placed")
	var directory: EntityDirectory = _nodes.directory()
	var previous_tile: int = -1
	var previous_id: int = 0
	for index: int in DEPOSIT_NODES:
		var tile: int = _footprint_tile(STONE_ORIGIN_X, STONE_ORIGIN_Z, index)
		assert_true(tile > previous_tile, "tile %d follows tile %d" % [tile, previous_tile])
		var id: int = directory.get_persistent_id(_nodes.ref_at_tile(tile))
		assert_true(id > previous_id,
			"tile %d's node was created after the node on tile %d" % [tile, previous_tile])
		assert_equal(_nodes.slot_at_tile(tile).value, index,
			"tile %d took row %d on a fresh store" % [tile, index])
		previous_tile = tile
		previous_id = id


func test_both_deposits_take_thirty_two_of_the_four_thousand_ninety_six_rows() -> void:
	"""R05-DEPOSIT-004: 32 rows, on 32 distinct tiles, holding 1500000 milli-U between them."""
	assert_true(_nodes.place_stone_deposit(
		RESOURCE_STONE, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE).ok, "stone is placed")
	assert_true(_nodes.place_iron_deposit(
		RESOURCE_IRON, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE).ok, "iron is placed")
	assert_equal(_nodes.count(), BOTH_DEPOSITS_NODES, "thirty-two live rows")
	assert_equal(_nodes.directory().live_count(EntityDirectory.KIND_RESOURCE_NODE),
		BOTH_DEPOSITS_NODES, "thirty-two directory rows")
	assert_equal(_nodes.directory().free_row_count(EntityDirectory.KIND_RESOURCE_NODE),
		EXPECTED_CAPACITY - BOTH_DEPOSITS_NODES, "4064 of the 4096 rows are still free")
	var occupied: int = 0
	var total: int = 0
	for tile: int in EXPECTED_TILE_COUNT:
		if not _nodes.has_node_at_tile(tile):
			continue
		occupied += 1
		total += _nodes.quantity_milli_of(_nodes.slot_at_tile(tile).value).value
	assert_equal(occupied, BOTH_DEPOSITS_NODES, "the two footprints do not overlap")
	assert_equal(total, STONE_TOTAL_MILLI + IRON_TOTAL_MILLI, "1200000 + 300000 milli-U")


func test_a_deposit_replaces_a_tree_on_its_footprint_without_stranding_the_row() -> void:
	"""R05-DEPOSIT-002: an explicit destroy, so the felled tree's directory row is released."""
	var corner: int = _place_tree(_tile(STONE_ORIGIN_X, STONE_ORIGIN_Z), FIRST_DAY)
	var middle: int = _place_tree(_tile(46, 72), FIRST_DAY)
	var far: int = _place_tree(_tile(47, 73), FIRST_DAY)
	var corner_ref: Vector2i = _nodes.ref_of(corner)
	var middle_ref: Vector2i = _nodes.ref_of(middle)
	var far_ref: Vector2i = _nodes.ref_of(far)
	assert_equal(_nodes.count(), 3, "three trees stand on the footprint")
	assert_true(_nodes.place_stone_deposit(
		RESOURCE_STONE, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE).ok, "the deposit is placed")
	assert_equal(_nodes.count(), DEPOSIT_NODES, "sixteen rows, not nineteen")
	assert_equal(_nodes.directory().live_count(EntityDirectory.KIND_RESOURCE_NODE),
		DEPOSIT_NODES, "the three tree rows were released, not stranded")
	for stale: Vector2i in [corner_ref, middle_ref, far_ref]:
		assert_false(_nodes.directory().is_valid(stale), "the tree reference no longer validates")
		var repeat: ResourceNodes.OpResult = _nodes.destroy(stale)
		assert_false(repeat.ok, "and cannot be destroyed a second time")
		assert_equal(repeat.error, "RESOURCE_NODE_NOT_PRESENT", "with the not-present code")
	assert_equal(_ore_node_quantity(STONE_ORIGIN_X, STONE_ORIGIN_Z, RESOURCE_STONE,
		STONE_NODE_MILLI), STONE_NODE_MILLI, "ore stands where the corner tree did")
	assert_equal(_ore_node_quantity(46, 72, RESOURCE_STONE, STONE_NODE_MILLI), STONE_NODE_MILLI,
		"ore stands where the middle tree did")


func test_a_deposit_refuses_a_foreign_occupant_and_changes_nothing() -> void:
	"""Only the caller's declared replaceable id may be felled; anything else refuses whole."""
	var tree: int = _place_tree(_tile(STONE_ORIGIN_X, STONE_ORIGIN_Z), FIRST_DAY)
	var tree_ref: Vector2i = _nodes.ref_of(tree)
	var foreign: ResourceNodes.OpResult = _nodes.create_at_tile(
		_tile(46, 72), RESOURCE_IRON, 5000, NON_RENEWABLE, FIRST_DAY)
	assert_true(foreign.ok, "an iron node stands inside the stone footprint")
	var refused: ResourceNodes.OpResult = _nodes.place_stone_deposit(
		RESOURCE_STONE, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE)
	assert_false(refused.ok, "the deposit is refused")
	assert_equal(refused.error, "FOOTPRINT_OCCUPIED", "with the footprint-occupied code")
	assert_equal(refused.value, 0, "a refusal carries no node count")
	assert_equal(refused.ref, EntityDirectory.NULL_REF, "and no reference")
	assert_equal(_nodes.count(), 2, "no ore row was created")
	assert_equal(_nodes.directory().live_count(EntityDirectory.KIND_RESOURCE_NODE), 2,
		"and no reserved directory row leaked")
	assert_true(_nodes.directory().is_valid(tree_ref), "the replaceable tree was not felled")
	assert_equal(_nodes.quantity_milli_of(tree).value, TREE_WOOD_MILLI, "with its stock intact")
	assert_equal(_nodes.quantity_milli_of(foreign.value).value, 5000, "the foreign node stands")
	assert_false(_nodes.has_node_at_tile(_tile(45, 70)), "no half-built deposit was left behind")
	assert_false(_nodes.has_node_at_tile(_tile(47, 73)), "on either side of the blocked tile")


func test_a_deposit_refuses_a_footprint_that_leaves_the_grid() -> void:
	"""The block runs to origin+3, so 125 refuses on either axis and 124 is the last that fits."""
	var cases: Array[Vector2i] = [
		Vector2i(125, 70), Vector2i(70, 125), Vector2i(-1, 70), Vector2i(70, -1),
		Vector2i(128, 0), Vector2i(0, 128),
	]
	for origin: Vector2i in cases:
		var refused: ResourceNodes.OpResult = _nodes.place_deposit(
			origin.x, origin.y, RESOURCE_STONE, STONE_NODE_MILLI, NON_RENEWABLE, FIRST_DAY,
			RESOURCE_TREE)
		assert_false(refused.ok, "origin (%d,%d) is refused" % [origin.x, origin.y])
		assert_equal(refused.error, "INVALID_FOOTPRINT", "with the footprint code")
	assert_equal(_nodes.count(), 0, "no refused footprint left a node behind")
	assert_equal(_nodes.directory().live_count(EntityDirectory.KIND_RESOURCE_NODE), 0,
		"and none leaked a directory row")
	var corner: ResourceNodes.OpResult = _nodes.place_deposit(
		124, 124, RESOURCE_STONE, STONE_NODE_MILLI, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE)
	assert_true(corner.ok, "a footprint ending on (127,127) fits")
	assert_true(_nodes.has_node_at_tile(_tile(127, 127)), "its far corner is the last tile")
	assert_equal(_nodes.count(), DEPOSIT_NODES, "sixteen nodes in the grid corner")


func test_a_deposit_refuses_every_unstorable_field_without_placing_a_node() -> void:
	"""A deposit validates each §4.2 field exactly as a single placement does, and refuses whole."""
	var cases: Array[Array] = [
		[-1, STONE_NODE_MILLI, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE, "INVALID_RESOURCE_ID"],
		[RESOURCE_STONE, 0, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE, "INVALID_CAPACITY"],
		[RESOURCE_STONE, -1, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE, "INVALID_CAPACITY"],
		[RESOURCE_STONE, STONE_NODE_MILLI, -1, FIRST_DAY, RESOURCE_TREE, "INVALID_REGROW_DAYS"],
		[RESOURCE_STONE, STONE_NODE_MILLI, NON_RENEWABLE, 0, RESOURCE_TREE, "INVALID_DAY"],
		[RESOURCE_STONE, STONE_NODE_MILLI, NON_RENEWABLE, FIRST_DAY, -1, "INVALID_RESOURCE_ID"],
	]
	for case: Array in cases:
		var refused: ResourceNodes.OpResult = _nodes.place_deposit(
			STONE_ORIGIN_X, STONE_ORIGIN_Z, case[0], case[1], case[2], case[3], case[4])
		assert_false(refused.ok, "refused: %s" % case[5])
		assert_equal(refused.error, case[5], "refusal code for %s" % case[5])
	assert_equal(_nodes.count(), 0, "no refused deposit left a row behind")
	assert_equal(_nodes.directory().live_count(EntityDirectory.KIND_RESOURCE_NODE), 0,
		"and none leaked a directory row")
	assert_false(_nodes.has_node_at_tile(_tile(STONE_ORIGIN_X, STONE_ORIGIN_Z)),
		"the origin tile is still empty")


func test_a_deposit_reserves_its_rows_before_it_fells_anything() -> void:
	"""Allocate before consume: fifteen free rows refuse and spare the tree; sixteen succeed."""
	var footprint_tree: int = _place_tree(_tile(STONE_ORIGIN_X, STONE_ORIGIN_Z), FIRST_DAY)
	var tree_ref: Vector2i = _nodes.ref_of(footprint_tree)
	var spare: int = _fill_trees(EXPECTED_CAPACITY - DEPOSIT_NODES)
	var directory: EntityDirectory = _nodes.directory()
	assert_equal(directory.free_row_count(EntityDirectory.KIND_RESOURCE_NODE), DEPOSIT_NODES - 1,
		"fifteen rows are free, one short of a deposit")
	var refused: ResourceNodes.OpResult = _nodes.place_stone_deposit(
		RESOURCE_STONE, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE)
	assert_false(refused.ok, "the deposit is refused")
	assert_equal(refused.error, "CAPACITY_RESOURCE_NODE", "with the directory's capacity code")
	assert_equal(directory.free_row_count(EntityDirectory.KIND_RESOURCE_NODE), DEPOSIT_NODES - 1,
		"every reserved row was handed back")
	assert_true(directory.is_valid(tree_ref), "the tree on the footprint was not felled")
	assert_equal(_nodes.quantity_milli_of(footprint_tree).value, TREE_WOOD_MILLI, "nor debited")
	assert_false(_nodes.has_node_at_tile(_tile(45, 70)), "and no ore node was published")
	assert_true(_nodes.destroy(_nodes.ref_of(spare)).ok, "one unrelated row is freed")
	var placed: ResourceNodes.OpResult = _nodes.place_stone_deposit(
		RESOURCE_STONE, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE)
	assert_true(placed.ok, "sixteen free rows are exactly enough")
	assert_false(directory.is_valid(tree_ref), "and now the tree is replaced")
	assert_equal(_ore_node_quantity(STONE_ORIGIN_X, STONE_ORIGIN_Z, RESOURCE_STONE,
		STONE_NODE_MILLI), STONE_NODE_MILLI, "ore stands on the origin tile")


func test_each_deposit_node_exhausts_independently_of_the_other_fifteen() -> void:
	"""R05-DEPOSIT-003: working one tile out leaves the other fifteen full and standing."""
	assert_true(_nodes.place_stone_deposit(
		RESOURCE_STONE, NON_RENEWABLE, FIRST_DAY, RESOURCE_TREE).ok, "the deposit is placed")
	var worked_out: int = _nodes.slot_at_tile(_tile(45, 71)).value
	assert_true(_nodes.harvest_all(worked_out, FIRST_DAY).ok, "one tile is worked out")
	assert_true(_nodes.is_exhausted(worked_out), "that node is exhausted")
	assert_equal(_nodes.quantity_milli_of(worked_out).value, 0, "and holds nothing")
	var partial: int = _nodes.slot_at_tile(_tile(47, 73)).value
	assert_true(_nodes.harvest(partial, 25000, FIRST_DAY).ok, "another tile is part-worked")
	var standing: int = 0
	var total: int = 0
	for index: int in DEPOSIT_NODES:
		var slot: int = _nodes.slot_at_tile(_footprint_tile(
			STONE_ORIGIN_X, STONE_ORIGIN_Z, index)).value
		total += _nodes.quantity_milli_of(slot).value
		if slot == worked_out or slot == partial:
			continue
		assert_false(_nodes.is_exhausted(slot), "row %d is untouched" % slot)
		assert_equal(_nodes.quantity_milli_of(slot).value, STONE_NODE_MILLI, "row %d is full" % slot)
		standing += 1
	assert_equal(standing, DEPOSIT_NODES - 2, "fourteen nodes were never touched")
	assert_equal(total, STONE_TOTAL_MILLI - STONE_NODE_MILLI - 25000, "1100000 milli-U remain")
	assert_equal(_nodes.count(), DEPOSIT_NODES, "the worked-out node is still a row on its tile")
