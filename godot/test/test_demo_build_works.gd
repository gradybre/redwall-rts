extends "res://test/framework/test_case.gd"
## The proof of concept's works (decision 1912): ordering rooms and ways down, opening cells, the breadth-first dig
## order from the way in, walking paths through dug cells and down a way down.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Items := preload("res://scripts/ui/build_items.gd")

var _works: Works = null


func before_each() -> void:
	"""A 32 × 32-cell area, all earth."""
	_works = Works.new()
	_works.configure(Rect2i(0, 0, 32, 32))


func _dig_all(from: Vector3i) -> Array[Vector3i]:
	"""Dig every reachable ordered cell from `from` (as the mole does: dig, then plan from where it stood); the order
	the cells opened in."""
	var opened: Array[Vector3i] = []
	var at: Vector3i = from
	for guard: int in 200:
		var found: Dictionary = _works.next_dig(at)
		if found.is_empty():
			break
		var path: PackedVector3Array = found["path"]
		at = Vector3i(path[path.size() - 1])
		var target: Vector3i = found["target"]
		assert_true(_works.open_cell(target.x, Vector2i(target.y, target.z)), "opens %s" % target)
		opened.append(target)
	return opened


func test_an_entrance_and_a_room_are_dug_outward_from_its_landing() -> void:
	"""The landing first (dug in place), then the room cells beside open space, nearest first, every one."""
	assert_true(_works.order_way_down(0, Vector2i(4, 4)), "the Entrance")
	assert_true(_works.order_room(1, PackedInt32Array([6, 4, 7, 4, 6, 5, 7, 5]), 2), "a 2 × 2 room beside it")
	assert_equal(_works.waiting(), 8, "8 cells wait")
	assert_equal(_works.entrance(), 0, "the first Entrance")
	assert_equal(_works.landing_of(0), Vector3i(1, 4, 4), "it lands on level 1")
	var opened: Array[Vector3i] = _dig_all(_works.landing_of(0))
	assert_equal(opened.size(), 8, "all dug")
	assert_equal(opened[0], Vector3i(1, 4, 4), "the landing under the mole first")
	assert_true(opened.find(Vector3i(1, 6, 4)) > opened.find(Vector3i(1, 5, 4)), "the room after the landing beside it")
	assert_equal(_works.waiting(), 0, "nothing waits")
	assert_equal(_works.type_of(1, Vector2i(6, 4)), 2, "the room's type kept")
	assert_equal(_works.type_of(1, Vector2i(4, 4)), Works.TYPE_NONE, "a landing has none")


func test_a_room_cut_off_from_the_way_in_is_never_dug() -> void:
	"""Only cells beside open space can be dug; a room across earth waits."""
	_works.order_way_down(0, Vector2i(4, 4))
	_works.order_room(1, PackedInt32Array([20, 20, 21, 20, 20, 21, 21, 21]), 2)
	assert_equal(_dig_all(Vector3i(1, 4, 4)).size(), 4, "only the landing")
	assert_equal(_works.waiting(), 4, "the far room waits")


func test_a_way_down_is_dug_from_above_and_walked_both_ways() -> void:
	"""A Way down standing on dug level-1 cells: its landing on level 2 is dug from above; then a walk crosses it."""
	_works.order_way_down(0, Vector2i(4, 4))
	_works.order_way_down(1, Vector2i(4, 4))
	_works.order_room(2, PackedInt32Array([6, 4, 6, 5]), 7)
	_dig_all(Vector3i(1, 4, 4))
	assert_equal(_works.state(2, Vector2i(4, 4)), Works.OPEN, "the level-2 landing dug")
	assert_equal(_works.state(2, Vector2i(6, 5)), Works.OPEN, "and the passage beyond it")
	var path: PackedVector3Array = _works.path_to(Vector3i(1, 5, 5), Vector3i(2, 6, 4))
	assert_false(path.is_empty(), "a walk from level 1 to level 2")
	assert_equal(Vector3i(path[path.size() - 1]), Vector3i(2, 6, 4), "ending there")
	assert_true(_works.path_to(Vector3i(2, 6, 4), Vector3i(1, 4, 4)).size() > 1, "and back up")
	assert_true(_works.path_to(Vector3i(1, 4, 4), Vector3i(1, 30, 30)).is_empty(), "no way to earth")


func test_orders_off_the_area_are_refused() -> void:
	"""Nothing is ordered past the area or below level 4; a cell not ordered does not open; the surface reads earth
	until a Mound room is ordered there."""
	assert_false(_works.order_room(1, PackedInt32Array([40, 40]), 2), "off the area")
	assert_false(_works.order_way_down(4, Vector2i(1, 1)), "nothing below level 4")
	assert_false(_works.order_way_down(0, Vector2i(31, 31)), "its landing past the area")
	assert_false(_works.open_cell(1, Vector2i(1, 1)), "earth does not open")
	assert_equal(_works.state(0, Vector2i(1, 1)), Works.EARTH, "the surface reads earth")
	assert_equal(_works.entrance(), -1, "no Entrance")
	assert_true(_works.next_dig(Vector3i(1, 1, 1)).is_empty(), "nothing to dig")


func test_a_mound_room_is_ordered_on_the_surface_and_waits_for_its_builder() -> void:
	"""Decision 2002: a Mound room's cells are ordered on the surface with their type; the mole's count leaves them out;
	dug, they open; a way down standing on them is on its way there, and `ways_on` names its north-west cell."""
	assert_true(_works.order_room(0, PackedInt32Array([1, 1, 2, 1]), 2), "a Mound Kitchen")
	assert_equal([_works.state(0, Vector2i(1, 1)), _works.type_of(0, Vector2i(2, 1))], [Works.ORDERED, 2], "ordered")
	assert_equal(_works.waiting(), 0, "not the mole's")
	assert_true(_works.open_cell(0, Vector2i(1, 1)), "dug by its builder")
	assert_equal(_works.waiting(), 0, "still none of the mole's")
	var cells: PackedInt32Array = PackedInt32Array()
	_works.cells_into(0, Works.OPEN, cells)
	assert_equal(cells, PackedInt32Array([1, 1]), "the surface's box is scanned")
	assert_true(_works.order_way_down(0, Vector2i(1, 1)), "a hatch on its floor")
	assert_true(_works.on_way(0, Vector2i(2, 2)) or _works.on_way(0, Vector2i(1, 1)), "its floor is a way's")
	assert_false(_works.on_way(0, Vector2i(9, 9)), "elsewhere on the surface: no")
	assert_equal(_works.ways_on(0), PackedInt32Array([1, 1]), "its north-west cell")
	assert_equal(_works.ways_on(1), PackedInt32Array(), "none stands below")


func test_a_repaint_keeps_cells_ordered_once() -> void:
	"""Ordering a cell twice waits once; a landing ordered over a room cell keeps the room's type."""
	_works.order_room(1, PackedInt32Array([4, 4, 5, 4]), 3)
	_works.order_room(1, PackedInt32Array([4, 4]), 3)
	assert_equal(_works.waiting(), 2, "two cells")
	_works.order_way_down(0, Vector2i(4, 4))
	assert_equal(_works.type_of(1, Vector2i(4, 4)), 3, "the room's type kept")
	assert_equal(_works.waiting(), 4, "the landing's other two")
	var revision: int = _works.revision
	_works.open_cell(1, Vector2i(4, 4))
	assert_true(_works.revision > revision, "a dug cell moves the revision")
	assert_equal(_works.way_count(), 1, "one way down")
	assert_equal(_works.way_level(0), 0, "the Entrance")
	assert_equal(_works.way_cell(0), Vector2i(4, 4), "its cell")


func test_a_second_entrance_is_reached_through_the_surface() -> void:
	"""Review H4: a room beside a second Entrance is dug from the first's landing, over the top."""
	_works.order_way_down(0, Vector2i(4, 4))
	_works.order_way_down(0, Vector2i(20, 20))
	_works.order_room(1, PackedInt32Array([22, 20, 23, 20, 22, 21, 23, 21]), 2)
	assert_equal(_dig_all(Vector3i(1, 4, 4)).size(), 12, "both landings and the room")
	assert_equal(_works.waiting(), 0, "nothing waits")
	var path: PackedVector3Array = _works.path_to(Vector3i(1, 4, 4), Vector3i(1, 22, 20))
	assert_true(path.has(Vector3(Works.SURFACE)), "the walk goes over the top")


func test_cells_into_scans_the_box_of_ordered_cells() -> void:
	"""Review H2: the cells of a state, from the level's box only, canonical."""
	_works.order_room(1, PackedInt32Array([10, 10, 11, 10]), 2)
	assert_equal(_works.box_of(1), Rect2i(10, 10, 2, 1), "the box")
	var out: PackedInt32Array = PackedInt32Array()
	_works.cells_into(1, Works.ORDERED, out)
	assert_equal(out, PackedInt32Array([10, 10, 11, 10]), "both")
	_works.cells_into(1, Works.OPEN, out)
	assert_true(out.is_empty(), "none dug")
	assert_equal(_works.box_of(2), Rect2i(), "level 2 has none")
