extends "res://test/framework/test_case.gd"
## Suite for `ground_piles.gd`'s existing-lot mover (task 06.4 H1, decision 1022):
## `move_container_into_piles()`, its preflight and `drop_seeds_into()`.
##
## The mover is DEC-043 #9's breadth-first walk and site rule applied to goods that already exist:
## they MOVE (never created, never sunk), whole lots keep their identity, a lot that does not fit
## one pile spills exactly to the next, and any refusal rolls every store back.

const HaulWorld := preload("res://test/fixtures/haul_world.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const GroundPilesScript := preload("res://scripts/core/ground_piles.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const STONE: int = HaulWorld.ITEM_STONE


class OneTilePassable:
	extends "res://scripts/core/ground_piles.gd"
	## Only tile (45, 45) is passable: a walk's whole component is one tile.

	func is_tile_passable(tile: int) -> bool:
		"""The one passable tile."""
		return tile == 45 * 128 + 45
const JOB: Vector2i = Vector2i(4, 1)

var _w: HaulWorld = null
var _box: Vector2i = Vector2i(-1, 0)
var _out: GroundPilesScript.PlaceResult = GroundPilesScript.PlaceResult.new()


func before_each() -> void:
	"""An unplaced satchel-like box: a satchel minted for a spawned mouse."""
	_w = HaulWorld.new()
	var mouse: int = _w.spawn(&"mouse")
	_box = _w.inventory.create_satchel(_w.residents.ref_of(mouse), 400000).ref


func _seed(tile: int) -> PackedInt32Array:
	"""A one-tile seed buffer."""
	return PackedInt32Array([tile])


func test_a_whole_lot_moves_onto_a_new_pile_keeping_its_identity() -> void:
	"""One lot, one pile on the seed tile, the same lot ref, storage class 1500."""
	var stones: Vector2i = _w.lot(_box, STONE, 5000)
	assert_true(_w.piles.move_container_into_piles(_box, _seed(HaulWorld.tile(45, 45)), 1,
		PackedByteArray(), _out), "moved: %s" % _out.error)
	var pile: Vector2i = _w.inventory.ground_pile_at_tile(HaulWorld.tile(45, 45))
	assert_equal(_w.inventory.lot_container(stones), pile, "the same lot, now on the pile")
	assert_equal(_out.piles_created, 1, "one pile")
	assert_equal(_out.lots_created, 1, "one lot arrived")
	assert_equal(_w.stock_age.storage_class_of(pile), StockAgeScript.STORAGE_OPEN_PILE, "1500")
	assert_equal(_w.inventory.total_sourced_milli(STONE), 5000, "nothing created")
	assert_true(_w.inventory.audit().ok, "audit")


func test_a_lot_too_big_for_the_seed_pile_spills_exactly_to_the_next_tile() -> void:
	"""A pile with 1000 g free takes 1 stone; the other 4 go north (DEC-043's N, E, S, W)."""
	_w.inventory.begin()
	var pile: Vector2i = _w.inventory.create_ground_pile(HaulWorld.tile(45, 45)).ref
	_w.lot(pile, STONE, 399000)
	assert_true(_w.inventory.commit().ok, "a nearly full pile")
	_w.lot(_box, STONE, 5000)
	assert_true(_w.piles.move_container_into_piles(_box, _seed(HaulWorld.tile(45, 45)), 1,
		PackedByteArray(), _out), "moved")
	assert_equal(_w.inventory.container_used_mass_g(pile), 400000, "topped up exactly")
	var north: Vector2i = _w.inventory.ground_pile_at_tile(HaulWorld.tile(45, 44))
	assert_equal(_w.inventory.container_used_mass_g(north), 4000, "the rest spilled north")
	assert_equal(_w.inventory.total_live_milli(STONE), 404000, "conserved")
	assert_true(_w.inventory.audit().ok, "audit")


func test_the_mover_refuses_claimed_empty_and_pile_sources() -> void:
	"""A reserved lot, an empty source and a pile source refuse, writing nothing."""
	var before: PackedByteArray = _w.inventory.state_bytes()
	assert_false(_w.piles.move_container_into_piles(_box, _seed(HaulWorld.tile(45, 45)), 1,
		PackedByteArray(), _out), "empty")
	assert_equal(_out.error, GroundPilesScript.REFUSE_MOVE_SOURCE, "named")
	var stones: Vector2i = _w.lot(_box, STONE, 5000)
	assert_true(_w.claim(JOB, stones, ReservationsScript.PURPOSE_HAUL_DESTINATION, 1000), "claimed")
	before = _w.state()
	assert_false(_w.piles.move_container_into_piles(_box, _seed(HaulWorld.tile(45, 45)), 1,
		PackedByteArray(), _out), "claimed")
	assert_equal(_out.error, GroundPilesScript.REFUSE_MOVE_SOURCE_RESERVED, "named")
	assert_equal(_w.state(), before, "byte-identical")
	assert_false(_w.piles.move_container_into_piles(_box, PackedInt32Array(), 1,
		PackedByteArray(), _out), "no seeds")
	assert_equal(_out.error, GroundPilesScript.REFUSE_SEED_SHAPE, "named")


func test_reserved_mass_on_the_source_refuses_the_move() -> void:
	"""Headroom held on the source is a claim the mover cannot carry."""
	_w.lot(_box, STONE, 1000)
	assert_true(_w.inventory.reserve_container_mass(_box, 10).ok, "held")
	assert_false(_w.piles.move_container_into_piles(_box, _seed(HaulWorld.tile(45, 45)), 1,
		PackedByteArray(), _out), "refused")
	assert_equal(_out.error, GroundPilesScript.REFUSE_MOVE_SOURCE_RESERVED, "named")


func test_the_preflight_sees_claimed_goods_as_released_and_changes_nothing() -> void:
	"""A claimed source passes the preflight when the walk fits, and nothing is kept."""
	var stones: Vector2i = _w.lot(_box, STONE, 5000)
	assert_true(_w.claim(JOB, stones, ReservationsScript.PURPOSE_HAUL_DESTINATION, 5000), "claimed")
	assert_true(_w.inventory.reserve_container_mass(_box, 10).ok, "and some headroom held")
	var before: PackedByteArray = _w.state()
	assert_true(_w.piles.preflight_container_into_piles(_box, _seed(HaulWorld.tile(45, 45)), 1,
		PackedByteArray(), _out), "it would fit: %s" % _out.error)
	assert_equal(_out.lots_created, 1, "it counted the move")
	assert_equal(_w.state(), before, "byte-identical")


func test_a_walk_with_no_room_refuses_and_rolls_back() -> void:
	"""Every tile refused: the first seed's refusal, every store unchanged."""
	_w.lot(_box, STONE, 5000)
	var yard: Vector2i = _w.place_active("open_stockpile", 40, 40)
	assert_true(yard != InventoryScript.NULL_REF, "a footprint")
	var before: PackedByteArray = _w.inventory.state_bytes()
	assert_false(_w.piles.move_container_into_piles(_box, _seed(HaulWorld.tile(41, 41)), 1,
		PackedByteArray(), _out), "on a standing footprint")
	assert_equal(_out.error, GroundPilesScript.REFUSE_INACCESSIBLE_FOOTPRINT, "named")
	assert_equal(_w.inventory.state_bytes(), before, "byte-identical")


func test_drop_seeds_are_the_tile_or_the_footprints_refund_origin() -> void:
	"""Off any footprint the tile itself; on one, that building's ring; off-grid refuses."""
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(GroundPilesScript.TILE_COUNT)
	var seeds: PackedInt32Array = PackedInt32Array()
	seeds.resize(GroundPilesScript.REFUND_SEED_CAPACITY)
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_w.piles.drop_seeds_into(HaulWorld.tile(45, 45), mask, seeds, out), "open ground")
	assert_equal(out.value, 1, "one seed")
	assert_equal(seeds[0], HaulWorld.tile(45, 45), "the tile")
	_w.place_active("open_stockpile", 40, 40)
	assert_true(_w.piles.drop_seeds_into(HaulWorld.tile(41, 41), mask, seeds, out), "a footprint")
	assert_equal(out.value, 16, "a 4 x 4 footprint's edge ring")
	assert_equal(seeds[0], HaulWorld.tile(41, 44), "front (south) first")
	assert_false(_w.piles.drop_seeds_into(-1, mask, seeds, out), "off the grid")
	assert_false(_w.piles.drop_seeds_into(0, mask, PackedInt32Array(), out), "a short buffer")


func test_the_preflight_splits_a_claimed_lot_as_the_move_would() -> void:
	"""A claimed lot that must spill over two piles needs the release the preflight makes."""
	_w.inventory.begin()
	var pile: Vector2i = _w.inventory.create_ground_pile(HaulWorld.tile(45, 45)).ref
	_w.lot(pile, STONE, 399000)
	assert_true(_w.inventory.commit().ok, "a nearly full pile")
	var stones: Vector2i = _w.lot(_box, STONE, 5000)
	assert_true(_w.claim(JOB, stones, ReservationsScript.PURPOSE_HAUL_DESTINATION, 5000), "claimed")
	var before: PackedByteArray = _w.state()
	assert_true(_w.piles.preflight_container_into_piles(_box, _seed(HaulWorld.tile(45, 45)), 1,
		PackedByteArray(), _out), "it would fit: %s" % _out.error)
	assert_equal(_out.lots_created, 2, "split over two piles")
	assert_equal(_w.state(), before, "byte-identical")


func test_a_full_component_refuses_no_capacity_and_rolls_back() -> void:
	"""One passable tile with 1000 g free cannot take 5 stone: NO_CAPACITY, nothing kept."""
	var piles: OneTilePassable = OneTilePassable.new()
	assert_true(piles.bind_stores(_w.inventory, _w.buildings, _w.stock_age), "bound")
	assert_true(piles.bind_world(_w.world), "world")
	_w.inventory.begin()
	var pile: Vector2i = _w.inventory.create_ground_pile(HaulWorld.tile(45, 45)).ref
	_w.lot(pile, STONE, 399000)
	assert_true(_w.inventory.commit().ok, "a nearly full pile")
	_w.lot(_box, STONE, 5000)
	var before: PackedByteArray = _w.inventory.state_bytes()
	assert_false(piles.move_container_into_piles(_box, _seed(HaulWorld.tile(45, 45)), 1,
		PackedByteArray(), _out), "no room")
	assert_equal(_out.error, GroundPilesScript.REFUSE_NO_CAPACITY, "named")
	assert_equal(_w.inventory.state_bytes(), before, "byte-identical")
