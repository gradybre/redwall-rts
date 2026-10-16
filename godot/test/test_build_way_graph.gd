extends "res://test/framework/test_case.gd"
## BUILD-REQ-017's connectivity check (decision 2021; Brendan's ruling P-D1-6 (a), "Real check now"): what a removal
## would cut off, from the outside through walkable cells and tagged links; something already out of reach never
## holds a removal back.

const Graph := preload("res://scripts/ui/build_way_graph.gd")

const ENTRANCE: int = 0
const SECOND: int = 1
const DOOR: int = 7

var _graph: Graph = null


func before_each() -> void:
	"""Level 1: a passage x 0-5 at z 0, with a Kitchen x 6-7 on it; an entrance into its west end."""
	_graph = Graph.new()
	_graph.add_cells(1, PackedInt32Array([0, 0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0]))
	_graph.add_link(Graph.OUTSIDE, Vector3i(1, 0, 0), ENTRANCE)
	_graph.add_target(Vector3i(1, 6, 0), "Kitchen (level 1)")
	_graph.add_target(Vector3i(1, 7, 0), "Kitchen (level 1)")


func test_the_only_way_in_cuts_off_what_lies_beyond_it() -> void:
	"""Removing the only entrance names the Kitchen, once."""
	assert_equal(_graph.cut_off(PackedInt32Array([ENTRANCE])), PackedStringArray(["Kitchen (level 1)"]), "cut off")
	assert_true(_graph.cut_off(PackedInt32Array()).is_empty(), "nothing removed, nothing cut off")


func test_a_second_way_in_lets_the_first_go() -> void:
	"""Another entrance into the Kitchen's end keeps everything reached."""
	_graph.add_link(Graph.OUTSIDE, Vector3i(1, 7, 0), SECOND)
	assert_true(_graph.cut_off(PackedInt32Array([ENTRANCE])).is_empty(), "the second still serves")
	assert_equal(_graph.cut_off(PackedInt32Array([ENTRANCE, SECOND])), PackedStringArray(["Kitchen (level 1)"]),
		"both together cut it off")


func test_something_already_out_of_reach_never_holds_a_removal_back() -> void:
	"""A room on level 2 with no way to it is unreached before and after: not named."""
	_graph.add_cells(2, PackedInt32Array([40, 40, 41, 40]))
	_graph.add_target(Vector3i(2, 40, 40), "Pantry (level 2)")
	assert_equal(_graph.cut_off(PackedInt32Array([ENTRANCE])), PackedStringArray(["Kitchen (level 1)"]), "only the Kitchen")


func test_a_way_between_levels_carries_the_reach_down_and_a_resident_is_named() -> void:
	"""A way from level 1's passage to level 2: removing it cuts off level 2's room and the resident standing there; a
	link to a cell that is not walkable reaches nothing."""
	_graph.add_cells(2, PackedInt32Array([3, 0, 3, 1]))
	_graph.add_link(Vector3i(1, 3, 0), Vector3i(2, 3, 0), SECOND)
	_graph.add_target(Vector3i(2, 3, 1), "Dormitory (level 2)")
	_graph.add_target(Vector3i(2, 3, 1), "Basil")
	assert_equal(_graph.cut_off(PackedInt32Array([SECOND])), PackedStringArray(["Dormitory (level 2)", "Basil"]),
		"room and resident")
	_graph.add_link(Vector3i(1, 5, 0), Vector3i(3, 5, 0), DOOR)
	assert_false(_graph.reached(PackedInt32Array()).has(Vector3i(3, 5, 0)), "nothing walkable there")


func test_a_mound_door_is_a_link_from_the_outside() -> void:
	"""A Mound's door joins the outside to its room; removing its only door cuts the room off, and a hatch below it
	with it."""
	_graph.add_cells(0, PackedInt32Array([20, 20, 21, 20]))
	_graph.add_target(Vector3i(0, 21, 20), "Bedroom (surface)")
	_graph.add_link(Graph.OUTSIDE, Vector3i(0, 20, 20), DOOR)
	_graph.add_cells(1, PackedInt32Array([21, 20]))
	_graph.add_link(Vector3i(0, 21, 20), Vector3i(1, 21, 20), SECOND)
	_graph.add_target(Vector3i(1, 21, 20), "Basil")
	assert_equal(_graph.cut_off(PackedInt32Array([DOOR])), PackedStringArray(["Bedroom (surface)", "Basil"]), "both")


func test_cells_join_only_their_four_neighbours_on_one_level() -> void:
	"""Diagonals and other levels are not neighbours."""
	_graph.add_cells(1, PackedInt32Array([8, 1]))
	_graph.add_target(Vector3i(1, 8, 1), "Diagonal")
	_graph.add_cells(2, PackedInt32Array([0, 0]))
	_graph.add_target(Vector3i(2, 0, 0), "Below")
	var reached: Dictionary = _graph.reached(PackedInt32Array())
	assert_false(reached.has(Vector3i(1, 8, 1)), "no diagonal step")
	assert_false(reached.has(Vector3i(2, 0, 0)), "no step down without a way")
	assert_true(reached.has(Vector3i(1, 7, 0)) and reached.has(Graph.OUTSIDE), "the passage and the outside")


func test_names_are_listed_then_counted() -> void:
	"""At most four names, then "and N more"."""
	assert_equal(Graph.names_text(PackedStringArray(["A", "B"])), "A, B", "two")
	assert_equal(Graph.names_text(PackedStringArray(["A", "B", "C", "D"])), "A, B, C, D", "four")
	assert_equal(Graph.names_text(PackedStringArray(["A", "B", "C", "D", "E", "F"])), "A, B, C, D and 2 more", "six")
	assert_equal(Graph.names_text(PackedStringArray()), "", "none")
