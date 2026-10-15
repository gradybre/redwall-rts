extends "res://test/framework/test_case.gd"
## Decision 1933 (C2.1), BUILD-REQ-012: the dig order of a confirmed room, on the ADR1161 Kitchen (2 x 2 cells, two
## layers) beside its old Corridor. Breadth-first across the floor from the cells touching open space, ties by cell
## index, bottom up within each column.

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const DigOrder := preload("res://scripts/core/underground_room_dig_order.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Space := preload("res://scripts/core/room_space.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _h: ForemanTests.Kitchen = null
var _room: Vector2i = NULL_REF


func before_each() -> void:
	"""One confirmed Kitchen per test."""
	_h = ForemanTests.Kitchen.new()
	_room = _h.confirmed_room()


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


func _key(x: int, y: int, z: int) -> int:
	"""The Site key of one Kitchen cube, relative to the fixture datum."""
	var site: Vector2i = _h.sites.site_at(Vector3i(Phase.X + x, Phase.FLOOR + y, Phase.Z + z))
	return _h.sites._site_key[site.x]


func _keys(cubes: Array[Vector3i]) -> PackedInt32Array:
	"""Keys of several cubes, in the given order."""
	var out: PackedInt32Array = PackedInt32Array()
	for cube: Vector3i in cubes: out.append(_key(cube.x, cube.y, cube.z))
	return out


func test_the_kitchen_opens_from_the_corridor_side_column_by_column_bottom_up() -> void:
	"""The two cells beside the Corridor come first (distance 0, lower z first), then the two behind them."""
	if _room == NULL_REF: return
	var order: DigOrder.Order = DigOrder.Order.new()
	assert_equal(DigOrder.order_into(_h.sites, _h._owner, _room, order), &"", "ordered")
	assert_equal(order.keys, _keys([Vector3i(2048, 0, 0), Vector3i(2048, 1024, 0), Vector3i(2048, 0, 1024),
		Vector3i(2048, 1024, 1024), Vector3i(3072, 0, 0), Vector3i(3072, 1024, 0), Vector3i(3072, 0, 1024),
		Vector3i(3072, 1024, 1024)]), "breadth-first, ties by cell index, bottom up")
	assert_equal(order.distance, PackedInt32Array([0, 0, 0, 0, 1, 1, 1, 1]), "distance from finished space")
	for at: int in order.rows.size():
		assert_equal(_h.sites._site_key[order.rows[at]], order.keys[at], "rows match keys")


func test_open_space_on_the_far_side_reverses_the_order() -> void:
	"""Seeded only from the east, the far cells come first; ties are still by cell index."""
	if _room == NULL_REF: return
	var cells: DigOrder.Cells = DigOrder.Cells.new()
	assert_equal(DigOrder.collect_into(_h.sites, _room, cells), &"", "collected")
	var east: PackedInt32Array = PackedInt32Array([Phase.X + 4096, Phase.FLOOR, Phase.Z, Phase.X + 5120, Phase.FLOOR + 1024, Phase.Z + 2048])
	var order: DigOrder.Order = DigOrder.Order.new()
	assert_equal(DigOrder.order_from_into(_h.sites, cells, east, order), &"", "ordered")
	assert_equal(order.keys, _keys([Vector3i(3072, 0, 0), Vector3i(3072, 1024, 0), Vector3i(3072, 0, 1024),
		Vector3i(3072, 1024, 1024), Vector3i(2048, 0, 0), Vector3i(2048, 1024, 0), Vector3i(2048, 0, 1024),
		Vector3i(2048, 1024, 1024)]), "east cells first")


func test_a_room_with_no_open_space_beside_it_has_no_way_in() -> void:
	"""BUILD-REQ-013's words in the order: no seed, a named refusal, and the caller's packet untouched."""
	if _room == NULL_REF: return
	var cells: DigOrder.Cells = DigOrder.Cells.new()
	assert_equal(DigOrder.collect_into(_h.sites, _room, cells), &"", "collected")
	var order: DigOrder.Order = DigOrder.Order.new()
	order.keys = PackedInt32Array([7])
	assert_equal(DigOrder.order_from_into(_h.sites, cells, PackedInt32Array(), order), DigOrder.REFUSE_NO_WAY_IN, "no way in")
	var sliver: PackedInt32Array = PackedInt32Array([Phase.X + 1024, Phase.FLOOR, Phase.Z, Phase.X + 2048, Phase.FLOOR + 512, Phase.Z + 1024])
	assert_equal(DigOrder.order_from_into(_h.sites, cells, sliver, order), DigOrder.REFUSE_NO_WAY_IN, "a sliver of air is not finished space")
	assert_equal(order.keys, PackedInt32Array([7]), "out unchanged")


func test_a_cell_no_step_reaches_is_tried_last() -> void:
	"""Two cells with a gap between them: the unreached one sorts after the reached one, at UNREACHED."""
	if _room == NULL_REF: return
	var cells: DigOrder.Cells = DigOrder.Cells.new()
	assert_equal(DigOrder.collect_into(_h.sites, _room, cells), &"", "collected")
	var keep: Array[int] = [0, 3] # (2048, z0) and (3072, z1024): not 4-connected without the other two.
	var narrowed: DigOrder.Cells = DigOrder.Cells.new()
	narrowed.floor_y = cells.floor_y
	var plane: int = _h.sites._domain.size_quanta.x * _h.sites._domain.size_quanta.z
	for index: int in cells.keys.size():
		var cell: int = cells.keys[index] % plane
		if cell == cells.cells[keep[0]] or cell == cells.cells[keep[1]]:
			narrowed.keys.append(cells.keys[index]); narrowed.rows.append(cells.rows[index])
	narrowed.cells = PackedInt32Array([cells.cells[keep[0]], cells.cells[keep[1]]])
	var west: PackedInt32Array = PackedInt32Array([Phase.X + 1024, Phase.FLOOR, Phase.Z, Phase.X + 2048, Phase.FLOOR + 1024, Phase.Z + 1024])
	var order: DigOrder.Order = DigOrder.Order.new()
	assert_equal(DigOrder.order_from_into(_h.sites, narrowed, west, order), &"", "ordered")
	assert_equal(order.distance, PackedInt32Array([0, 0, DigOrder.UNREACHED, DigOrder.UNREACHED]), "reached, then unreached")
	assert_equal(order.keys[2], _key(3072, 0, 1024), "the unreached column, bottom first")


func test_collect_reads_every_site_of_the_room_and_its_floor() -> void:
	"""Keys ascending, one entry per horizontal cell, the floor layer of the lowest Site."""
	if _room == NULL_REF: return
	var cells: DigOrder.Cells = DigOrder.Cells.new()
	assert_equal(DigOrder.collect_into(_h.sites, _room, cells), &"", "collected")
	assert_equal(cells.keys.size(), ForemanTests.KITCHEN_SITES, "eight Sites")
	assert_equal(cells.cells.size(), 4, "four cells")
	var sorted: PackedInt32Array = cells.keys.duplicate(); sorted.sort()
	assert_equal(cells.keys, sorted, "ascending keys")
	var plane: int = _h.sites._domain.size_quanta.x * _h.sites._domain.size_quanta.z
	@warning_ignore("integer_division") var floor_y: int = _key(2048, 0, 0) / plane
	assert_equal(cells.floor_y, floor_y, "the floor layer")


func test_open_regions_and_cube_origins_read_the_live_owners() -> void:
	"""The Corridor's open region is found; the lattice decode equals Sites' own."""
	if _room == NULL_REF: return
	var cells: DigOrder.Cells = DigOrder.Cells.new()
	assert_equal(DigOrder.collect_into(_h.sites, _room, cells), &"", "collected")
	var voids: PackedInt32Array = PackedInt32Array()
	DigOrder.open_regions_into(_h._owner, _h.sites, cells, voids)
	assert_true(voids.size() >= 6, "at least the Corridor's open box")
	assert_equal(voids.slice(0, 6), PackedInt32Array([Phase.X - 4096, Phase.FLOOR, Phase.Z - 2048, Phase.X + 2048, Phase.FLOOR + 4096, Phase.Z + 4096]), "the Corridor")
	var site: Vector2i = Vector2i(cells.rows[0], Sites.SITE_GENERATION)
	var plane: int = _h.sites._domain.size_quanta.x * _h.sites._domain.size_quanta.z
	var key: int = cells.keys[0]
	@warning_ignore("integer_division") var origin: Vector3i = DigOrder.cube_origin(_h.sites, key % _h.sites._domain.size_quanta.x, key / plane, (key % plane) / _h.sites._domain.size_quanta.x)
	assert_equal(origin, _h.sites.origin_of(site), "same decode as Sites")


func test_refusals_are_named() -> void:
	"""Missing owners or packet, a null room, and a room with no Sites."""
	if _room == NULL_REF: return
	var order: DigOrder.Order = DigOrder.Order.new()
	assert_equal(DigOrder.order_into(null, _h._owner, _room, order), DigOrder.REFUSE_SCOPE, "no Sites")
	assert_equal(DigOrder.order_into(_h.sites, null, _room, order), DigOrder.REFUSE_SCOPE, "no owner")
	assert_equal(DigOrder.order_into(_h.sites, _h._owner, _room, null), DigOrder.REFUSE_SCOPE, "no packet")
	assert_equal(DigOrder.order_into(_h.sites, _h._owner, NULL_REF, order), DigOrder.REFUSE_SCOPE, "null room")
	assert_equal(DigOrder.order_into(_h.sites, _h._owner, Vector2i(_room.x, _room.y + 1), order), DigOrder.REFUSE_EMPTY, "no Site of that room")
	assert_equal(DigOrder.collect_into(null, _room, DigOrder.Cells.new()), DigOrder.REFUSE_SCOPE, "collect without Sites")
	assert_equal(order.keys.size(), 0, "nothing written")
