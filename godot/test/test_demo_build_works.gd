extends "res://test/framework/test_case.gd"
## The proof of concept's works (decision 1912): ordering rooms and ways down, opening cells, the breadth-first dig
## order from the way in, walking paths through dug cells and down a way down.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Items := preload("res://scripts/ui/build_items.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")

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


# --- per family (decision 2021) -------------------------------------------------------------------------------------

func test_a_burrow_mouth_orders_its_run_and_landing_and_is_dug_up_from_its_foot() -> void:
	"""A ramp from the Surface: its 2 × 12 lower cells wait (the last row its landing, the rest its run); the mole lands
	at its foot and digs the run back toward the top along itself; it is found by its shape, landing and family."""
	assert_true(_works.order_way_down(0, Vector2i(4, 2), Families.RAMP, 0), "ordered")
	assert_equal(_works.waiting(), 24, "2 × 12 cells below")
	assert_equal(_works.type_of(1, Vector2i(4, 2)), Works.TYPE_NONE, "the landing row")
	assert_equal(_works.type_of(1, Vector2i(4, 9)), Works.TYPE_WAY, "the run")
	assert_equal(_works.landing_of(0), Vector3i(1, 4, 2), "its foot 2 × 2")
	assert_equal(_works.way_cell(0), Vector2i(4, 14), "its top 2 × 2")
	assert_equal(_works.shapes_on(0), PackedInt32Array([4, 2, Families.RAMP, 0]), "its shape")
	assert_equal(_works.landings_on(1), PackedInt32Array([4, 2, 5, 2]), "its landing")
	assert_true(_works.hatches_on(0).is_empty(), "no hatch")
	assert_equal(_works.way_row_at(0, Vector2i(4, 2)), 0, "found by its anchor")
	var opened: Array[Vector3i] = _dig_all(_works.landing_of(0))
	assert_equal(opened.size(), 24, "all of it dug")
	assert_equal(opened[0], Vector3i(1, 4, 2), "the foot first")
	assert_true(opened.find(Vector3i(1, 4, 13)) > opened.find(Vector3i(1, 4, 3)), "up the run from the foot")


func test_a_run_is_walked_only_along_itself() -> void:
	"""A dug room beside a dug run is not entered from the run's side, only through the landing."""
	_works.order_way_down(0, Vector2i(4, 2), Families.RAMP, 0)
	_works.order_room(1, PackedInt32Array([6, 8, 7, 8, 6, 9, 7, 9]), 2)
	_dig_all(_works.landing_of(0))
	assert_equal(_works.state(1, Vector2i(6, 8)), Works.ORDERED, "the room beside the run is never reached")
	_works.order_room(1, PackedInt32Array([6, 2, 7, 2, 6, 3, 7, 3]), 2)
	assert_equal(_dig_all(_works.landing_of(0)).size(), 4, "beside the landing it is; the first still is not")
	assert_false(_works.path_to(Vector3i(1, 4, 12), Vector3i(1, 6, 2)).is_empty(), "walked down the run and out")


func test_a_way_below_links_its_top_to_its_foot() -> void:
	"""A stair standing on level 1 leads from its top 2 × 2 to its landing row on level 2, both ways (2043's M5:
	2 × 27, its landing 26 rows on)."""
	_works.configure(Rect2i(0, 0, 64, 64))
	_works.order_way_down(0, Vector2i(10, 10))
	_works.order_room(1, PackedInt32Array([10, 12, 11, 12, 10, 13, 11, 13]), 7)
	assert_true(_works.order_way_down(1, Vector2i(10, 12), Families.EARTH_TIMBER, 2), "a stair on level 1, turned south")
	assert_equal(_works.landing_of(1), Vector3i(2, 10, 37), "its foot 25 rows south")
	assert_true(_dig_all(_works.landing_of(0)).size() >= 6, "dug from the entrance down")
	assert_equal(_works.state(2, Vector2i(10, 38)), Works.OPEN, "its landing dug")
	assert_false(_works.path_to(Vector3i(2, 10, 38), Vector3i(1, 11, 13)).is_empty(), "walked back up")


func test_removing_a_way_returns_its_waiting_cells_and_keeps_dug_ones() -> void:
	"""P-D1-6 (a): a removed way stops standing; its cells still waiting go back to earth, its dug ones stay, bare."""
	_works.order_way_down(0, Vector2i(4, 4))
	_works.order_way_down(0, Vector2i(20, 4), Families.RAMP, 0)
	_works.open_cell(1, Vector2i(4, 4))
	var waiting: int = _works.waiting()
	assert_true(_works.remove_way_at(0, Vector2i(4, 4)), "removed")
	assert_false(_works.way_live(0), "no longer standing")
	assert_equal(_works.state(1, Vector2i(4, 4)), Works.OPEN, "a dug cell stays dug")
	assert_equal(_works.state(1, Vector2i(5, 5)), Works.EARTH, "a waiting one goes back")
	assert_equal(_works.waiting(), waiting - 3, "three fewer wait")
	assert_equal(_works.entrance(), 1, "the other entrance now")
	assert_true(_works.shapes_on(0).size() == 4 and _works.ways_on(0) == PackedInt32Array([20, 4]), "only the ramp")
	assert_false(_works.remove_way_at(0, Vector2i(4, 4)), "not twice")
	assert_equal(_works.way_row_at(0, Vector2i(4, 4)), -1, "not found")
	assert_false(_works.order_way_down(0, Vector2i(30, 30), Families.RAMP, 0), "off the area: refused")
	assert_false(_works.order_way_down(0, Vector2i(1, 1), 9, 0), "no family: refused")


func test_the_drawn_directions_and_the_stair_heads() -> void:
	"""Stairs go down the way it descends; a hatch's rise the same way, a run's back toward its top; the head cells lie
	just past the foot 2 × 2 that way."""
	_works.order_way_down(0, Vector2i(4, 4))
	_works.order_way_down(0, Vector2i(10, 2), Families.RAMP, 1)
	assert_equal(_works.down_dir(0), Vector2i(0, -1), "a hatch at turn 0 goes north")
	assert_equal(_works.rise_dir(0), Vector2i(0, -1), "and rises north at its landing")
	assert_equal(_works.head_cells(0), [Vector2i(4, 3), Vector2i(5, 3)], "its heads north of the landing")
	assert_equal(_works.down_dir(1), Vector2i(1, 0), "a ramp turned once descends east")
	assert_equal(_works.rise_dir(1), Vector2i(-1, 0), "its foot rises back west")
	var foot: Vector3i = _works.landing_of(1)
	assert_equal(_works.head_cells(1), [Vector2i(foot.y - 1, foot.z), Vector2i(foot.y - 1, foot.z + 1)], "heads west")
	assert_true(_works.on_way(1, Vector2i(15, 3)), "its run is on the way")
	assert_false(_works.on_way(0, Vector2i(15, 3)), "the Surface's open ground is not")


func test_removing_a_ramp_returns_its_waiting_run_to_earth() -> void:
	"""Mutation W8: a removed ramp's waiting run cells (TYPE_WAY) go back to earth, its landing too, and nothing waits."""
	_works.order_way_down(0, Vector2i(4, 2), Families.RAMP, 0)
	assert_true(_works.remove_way_at(0, Vector2i(4, 2)), "removed")
	assert_equal(_works.state(1, Vector2i(4, 9)), Works.EARTH, "its run")
	assert_equal(_works.type_of(1, Vector2i(4, 9)), Works.TYPE_NONE, "no longer a run")
	assert_equal(_works.state(1, Vector2i(4, 2)), Works.EARTH, "its landing")
	assert_equal(_works.waiting(), 0, "nothing waits")


func test_a_run_is_left_only_onto_its_own_landing_and_never_onto_another_run() -> void:
	"""Review H4: from a ramp's run, a hatch's landing beside it is no step; two runs side by side do not join."""
	_works.order_way_down(0, Vector2i(10, 2), Families.RAMP, 0)
	_works.order_way_down(0, Vector2i(12, 8), Families.LADDER_HATCH, 0)
	_works.order_way_down(0, Vector2i(14, 2), Families.RAMP, 0)
	for cell: Vector2i in [Vector2i(11, 8), Vector2i(12, 8), Vector2i(11, 9), Vector2i(13, 8), Vector2i(14, 8)]:
		_works.open_cell(1, cell)
	assert_true(_works.path_to(Vector3i(1, 11, 8), Vector3i(1, 12, 8)).is_empty(), "no step sideways to the hatch")
	assert_true(_works.path_to(Vector3i(1, 13, 8), Vector3i(1, 14, 8)).is_empty(), "no step from the hatch to a run")
	assert_false(_works.path_to(Vector3i(1, 11, 9), Vector3i(1, 11, 8)).is_empty(), "along the run")


func test_removing_one_way_keeps_cells_another_still_takes() -> void:
	"""Review H2: a removed way's cells that another standing way takes are left as they are."""
	_works.order_way_down(0, Vector2i(4, 4))
	_works.order_way_down(0, Vector2i(4, 4), Families.LADDER_HATCH, 1)
	assert_true(_works.remove_way_at(0, Vector2i(4, 4)), "the first removed")
	assert_equal(_works.state(1, Vector2i(4, 4)), Works.ORDERED, "still waiting for the other")


func test_two_runs_side_by_side_never_join() -> void:
	"""Mutation H4a: two ramps' runs in neighbouring columns are two ways, not one floor."""
	_works.order_way_down(0, Vector2i(10, 2), Families.RAMP, 0)
	_works.order_way_down(0, Vector2i(12, 2), Families.RAMP, 0)
	_works.open_cell(1, Vector2i(11, 8))
	_works.open_cell(1, Vector2i(12, 8))
	assert_true(_works.path_to(Vector3i(1, 11, 8), Vector3i(1, 12, 8)).is_empty(), "no step across")
