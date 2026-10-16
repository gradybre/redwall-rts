extends "res://test/framework/test_case.gd"
## Mound homes' rules (decision 2002; build_mound.gd): cell edges, outer edges, a door's two edges and its yard, the
## heap's footprint over the rooms, Mounds as joined rooms, and the ruled words.

const Mound := preload("res://scripts/ui/build_mound.gd")

## A 4 × 2 room at (2, 2)-(5, 3) and a 2 × 2 room joined to its east at (6, 2)-(7, 3).
var _rooms: Dictionary = {}


func before_each() -> void:
	"""The two joined rooms."""
	_rooms = Mound.set_of(_cells(Rect2i(2, 2, 6, 2)))


static func _cells(rect: Rect2i) -> PackedInt32Array:
	"""A rectangle's cells as pairs, row by row."""
	var out: PackedInt32Array = PackedInt32Array()
	for z: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			out.append_array(PackedInt32Array([x, z]))
	return out


func _is_room(cell: Vector2i) -> bool:
	"""The fixture's room reader."""
	return _rooms.has(cell)


func test_styles_and_sides() -> void:
	"""Two styles; the four sides step out north, east, south, west and run east or south along."""
	assert_true(Mound.valid_style(Mound.STYLE_BUILT) and Mound.valid_style(Mound.STYLE_MOUND), "both styles")
	assert_false(Mound.valid_style(-1) or Mound.valid_style(Mound.STYLE_COUNT), "nothing else")
	assert_equal(Mound.step_of(0), Vector2i(0, -1), "north")
	assert_equal(Mound.step_of(1), Vector2i(1, 0), "east")
	assert_equal(Mound.step_of(2), Vector2i(0, 1), "south")
	assert_equal(Mound.step_of(3), Vector2i(-1, 0), "west")
	assert_equal(Mound.step_of(-1), Vector2i(-1, 0), "turns wrap")
	assert_equal(Mound.along(0), Vector2i(1, 0), "a north edge runs east")
	assert_equal(Mound.along(2), Vector2i(1, 0), "a south edge runs east")
	assert_equal(Mound.along(1), Vector2i(0, 1), "an east edge runs south")
	assert_equal(Mound.along(3), Vector2i(0, 1), "a west edge runs south")


func test_an_edge_its_cell_and_the_cell_beyond() -> void:
	"""An edge names its room cell and its side; the cell beyond is a step out."""
	var edge: Vector3i = Vector3i(4, 2, 0)
	assert_equal(Mound.cell_of(edge), Vector2i(4, 2), "its cell")
	assert_equal(Mound.outside_of(edge), Vector2i(4, 1), "beyond it, north")
	assert_equal(Mound.outside_of(Vector3i(7, 3, 1)), Vector2i(8, 3), "beyond an east edge")


func test_outer_edges_face_no_room() -> void:
	"""An outer edge is a room cell's side whose other cell is in no room; the shared wall is not one."""
	assert_true(Mound.is_outer(Vector3i(2, 2, 0), _is_room), "the north wall")
	assert_true(Mound.is_outer(Vector3i(2, 2, 3), _is_room), "the west wall")
	assert_false(Mound.is_outer(Vector3i(5, 2, 1), _is_room), "the wall between the two rooms")
	assert_false(Mound.is_outer(Vector3i(3, 2, 2), _is_room), "between two cells of one room")
	assert_false(Mound.is_outer(Vector3i(0, 0, 2), _is_room), "no room's cell")
	var out: Array[Vector3i] = []
	Mound.outer_edges_into(_cells(Rect2i(2, 2, 6, 2)), _is_room, out)
	assert_equal(out.size(), 16, "6 north, 6 south, 2 west, 2 east")
	assert_true(out.has(Vector3i(7, 3, 1)) and out.has(Vector3i(2, 3, 2)), "the corners' sides")
	out.append(Vector3i.ZERO)
	Mound.outer_edges_into(PackedInt32Array(), _is_room, out)
	assert_true(out.is_empty(), "cleared first")


func test_a_door_takes_two_edges_along_its_side_and_a_window_one() -> void:
	"""A door's second edge is the next cell along the wall (east, or south); a window has one edge."""
	assert_equal(Mound.edges_of(Mound.KIND_DOOR, Vector2i(3, 2), 0), [Vector3i(3, 2, 0), Vector3i(4, 2, 0)] as Array[Vector3i],
		"north: east along")
	assert_equal(Mound.edges_of(Mound.KIND_DOOR, Vector2i(7, 2), 1), [Vector3i(7, 2, 1), Vector3i(7, 3, 1)] as Array[Vector3i],
		"east: south along")
	assert_equal(Mound.edges_of(Mound.KIND_WINDOW, Vector2i(3, 2), 6), [Vector3i(3, 2, 2)] as Array[Vector3i],
		"a window; its side wrapped")


func test_one_edge_named_from_either_side() -> void:
	"""The line between two cells is one edge whichever cell names it."""
	assert_true(Mound.same_edge(Vector3i(3, 2, 0), Vector3i(3, 2, 0)), "itself")
	assert_true(Mound.same_edge(Vector3i(3, 2, 0), Vector3i(3, 1, 2)), "named from the north")
	assert_true(Mound.same_edge(Vector3i(5, 2, 1), Vector3i(6, 2, 3)), "named from the east")
	assert_false(Mound.same_edge(Vector3i(3, 2, 0), Vector3i(3, 1, 0)), "a parallel edge")
	assert_false(Mound.same_edge(Vector3i(3, 2, 0), Vector3i(4, 1, 2)), "the next one along")


func test_the_yard_is_six_cells_wide_to_the_berms_foot() -> void:
	"""P-2001-5 (a): the door's two cells and two more each side, out three cells."""
	var yard: Dictionary = Mound.set_of(Mound.yard_cells(Vector2i(3, 2), 0))
	assert_equal(yard.size(), (Mound.DOOR_EDGES + 2 * Mound.YARD_SIDE_CELLS) * Mound.BERM_CELLS, "6 × 3 cells")
	assert_true(yard.has(Vector2i(1, 1)) and yard.has(Vector2i(6, 1)), "two cells past each end of the door")
	assert_true(yard.has(Vector2i(3, -1)) and not yard.has(Vector2i(3, -2)), "out to the berm's foot, no further")
	assert_false(yard.has(Vector2i(0, 1)) or yard.has(Vector2i(7, 1)), "no wider")
	assert_false(yard.has(Vector2i(3, 2)), "never the room's own cell")
	var east: Dictionary = Mound.set_of(Mound.yard_cells(Vector2i(7, 2), 1))
	assert_true(east.has(Vector2i(8, 0)) and east.has(Vector2i(10, 5)), "an east door's yard runs south")


func test_a_yard_must_be_clear_of_rooms() -> void:
	"""A room standing in a door's yard would open its wall: the yard is clear only with none."""
	assert_true(Mound.yard_clear(Vector2i(3, 2), 0, _is_room), "nothing north of the rooms")
	assert_false(Mound.yard_clear(Vector2i(3, 4), 0, _is_room), "a door facing into the rooms")


func test_the_heaps_footprint_rolls_three_cells_out() -> void:
	"""BUILD-MOUND-003 / P-2001-4 (a): covered while gx² + gz² < 9, never a room cell, rounded at the corners."""
	var cover: Dictionary = {Vector2i(99, 99): true}
	Mound.footprint_into(_cells(Rect2i(2, 2, 6, 2)), cover)
	assert_false(cover.has(Vector2i(99, 99)), "cleared first")
	assert_false(cover.has(Vector2i(3, 2)), "no room cell")
	assert_true(cover.has(Vector2i(3, 1)) and cover.has(Vector2i(3, -1)), "the first and third cells out")
	assert_false(cover.has(Vector2i(3, -2)), "not the fourth")
	assert_true(cover.has(Vector2i(0, 0)), "beyond the corner, gap (1, 1)")
	assert_true(cover.has(Vector2i(-1, 0)), "gap (2, 1): 5 < 9")
	assert_true(cover.has(Vector2i(-1, -1)), "gap (2, 2): 8 < 9")
	assert_false(cover.has(Vector2i(-2, -1)), "gap (3, 2): rounded off at the corner")
	assert_true(Mound.covered(Vector2i(2, 2)), "gap (2, 2): 8 < 9")
	assert_false(Mound.covered(Vector2i(3, 0)), "gap (3, 0): 9 is not < 9")
	assert_true(Mound.covered(Vector2i(0, 0)), "touching")


func test_gaps_between_cells() -> void:
	"""Whole cells between two cells' squares, each way."""
	assert_equal(Mound.gap_between(Vector2i(0, 0), Vector2i(0, 0)), Vector2i.ZERO, "one cell")
	assert_equal(Mound.gap_between(Vector2i(0, 0), Vector2i(1, 1)), Vector2i.ZERO, "touching at a corner")
	assert_equal(Mound.gap_between(Vector2i(0, 0), Vector2i(-3, 2)), Vector2i(2, 1), "either sign")


func test_mounds_are_rooms_joined_cell_to_cell() -> void:
	"""Joined rooms are one Mound; a gap of a cell makes two; the first cell's group comes first."""
	var cells: PackedInt32Array = _cells(Rect2i(0, 0, 2, 2))
	cells.append_array(_cells(Rect2i(3, 0, 2, 2)))
	cells.append_array(_cells(Rect2i(2, 0, 1, 1)))
	var groups: Array[PackedInt32Array] = Mound.components(cells)
	assert_equal(groups.size(), 1, "joined through the bridging cell")
	assert_equal(groups[0].size(), cells.size(), "every cell")
	var apart: Array[PackedInt32Array] = Mound.components(_cells(Rect2i(0, 0, 2, 2)) + _cells(Rect2i(3, 0, 2, 2)))
	assert_equal(apart.size(), 2, "a cell between: two Mounds")
	assert_true(Mound.set_of(apart[0]).has(Vector2i(0, 0)), "the first cell's first")
	assert_true(Mound.components(PackedInt32Array()).is_empty(), "none")


func test_the_words() -> void:
	"""The ruled words, and their builders."""
	assert_equal(Mound.TEXT_NO_DOOR, "No way in: place a door on an outer edge", "BUILD-MOUND-012")
	assert_equal(Mound.TEXT_DOOR_PAIR, "A door needs two free outer edges side by side", "BUILD-MOUND-029")
	assert_equal(Mound.TEXT_SURFACE_ONLY, "Mound rooms are painted on the Surface", "BUILD-MOUND-028")
	assert_equal(Mound.hill_covers("water"), "the hill would cover water", "BUILD-MOUND-008")
	assert_equal(Mound.kind_name(Mound.KIND_DOOR), "Front door", "the door")
	assert_equal(Mound.kind_name(Mound.KIND_WINDOW), "Window", "the window")
	assert_equal(Mound.kind_name(7), "", "neither")
	assert_equal(Mound.colour_name(Mound.COLOUR_OAK), "Oak", "oak first (P-2001-8 (a))")
	assert_equal(Mound.colour_name(1), "Green", "green still a choice")
	assert_equal(Mound.colour_name(-1), "Oak", "oak for an unknown one")
	assert_equal(Mound.covers_edge_item(Mound.KIND_WINDOW), "this would cover the Window on a room's outer edge; remove it first",
		"the removal review's stand-in")
	assert_equal(Mound.edge_taken(Mound.KIND_DOOR), "this edge already holds a front door; click it to remove it", "taken")
