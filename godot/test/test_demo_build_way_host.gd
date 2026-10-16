extends "res://test/framework/test_case.gd"
## The demo's cut-off reader (decision 2021; BUILD-REQ-017, Brendan's "Real check now"): the proof of concept's works,
## Mounds and residents below described to build_way_graph.gd, and what removing ways and doors would cut off.

const WayHost := preload("res://demo/build_panel/demo_build_way_host.gd")
const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Mounds := preload("res://demo/build_panel/demo_build_mounds.gd")
const Families := preload("res://scripts/ui/build_connector_families.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")

const KITCHEN: int = 2
const BEDROOM: int = 1

var _works: Works = null
var _mounds: Mounds = null
var _host: WayHost = null
var _below: Array = []


func before_each() -> void:
	"""A 64 × 64-cell area: an entrance (a hatch) at (4, 4) and a Kitchen beside its landing on level 1."""
	_works = Works.new()
	_works.configure(Rect2i(0, 0, 64, 64))
	_mounds = Mounds.new()
	_mounds.configure(Rect2i(0, 0, 64, 64))
	_below.clear()
	_host = WayHost.new()
	_host.configure(_works, _mounds, func() -> Array: return _below)
	_works.order_way_down(0, Vector2i(4, 4))
	_works.order_room(1, PackedInt32Array([6, 4, 7, 4, 6, 5, 7, 5]), KITCHEN)


func after_each() -> void:
	"""Let go (the reader's lambda holds this suite)."""
	_host = null


func test_removing_the_only_entrance_names_the_room_beyond() -> void:
	"""Ordered or dug, the Kitchen is reached only through the entrance."""
	assert_equal(_host.cut_off(PackedInt32Array([0, 4, 4]), []), "Kitchen (level 1)", "cut off")
	assert_equal(_host.cut_off(PackedInt32Array(), []), "", "nothing removed")
	assert_equal(_host.cut_off(PackedInt32Array([0, 30, 30]), []), "", "no way there: nothing removed")


func test_a_second_entrance_lets_the_first_go() -> void:
	"""A burrow mouth whose foot opens beside the Kitchen keeps it reached."""
	_works.order_way_down(0, Vector2i(8, 2), Families.RAMP, 0)
	assert_equal(_works.landings_on(1), PackedInt32Array([4, 4, 5, 4, 4, 5, 5, 5, 8, 2, 9, 2]), "two landings")
	_works.order_room(1, PackedInt32Array([6, 2, 7, 2, 6, 3, 7, 3]), 7)
	assert_equal(_host.cut_off(PackedInt32Array([0, 4, 4]), []), "", "the burrow mouth still serves")
	assert_equal(_host.cut_off(PackedInt32Array([0, 4, 4, 0, 8, 2]), []), "Passage (level 1), Kitchen (level 1)",
		"both cut everything off")


func test_a_resident_below_is_named() -> void:
	"""A resident standing in the Kitchen is cut off with it; one in unreached earth is not named."""
	_below.append(["Basil", Vector3i(1, 6, 4)])
	_below.append(["Lost", Vector3i(3, 40, 40)])
	assert_equal(_host.cut_off(PackedInt32Array([0, 4, 4]), []), "Kitchen (level 1), Basil", "both")


func test_a_way_further_down_and_its_run_are_one_way() -> void:
	"""A stair on the level-1 Passage down to level 2: removing it cuts off level 2's room, never its run's cells."""
	_works.order_room(1, PackedInt32Array([4, 6, 5, 6, 4, 7, 5, 7]), 7)
	_works.order_way_down(1, Vector2i(4, 6), Families.EARTH_TIMBER, 2)
	var foot: Vector3i = _works.landing_of(1)
	_works.order_room(2, PackedInt32Array([foot.y + 2, foot.z, foot.y + 3, foot.z, foot.y + 2, foot.z + 1,
		foot.y + 3, foot.z + 1]), BEDROOM)
	assert_equal(_host.cut_off(PackedInt32Array([1, 4, 6]), []), "Bedroom (level 2)", "the room below")
	assert_equal(_host.builds, 1, "one graph a question")


func test_a_mounds_only_door_cuts_off_its_rooms_and_the_hatch_below() -> void:
	"""A Mound with one door and a hatch on its floor down to a room on level 1: its door's removal cuts off both."""
	var room: PackedInt32Array = PackedInt32Array([20, 20, 21, 20, 20, 21, 21, 21])
	assert_true(_mounds.order_cells(room) and _works.order_room(Mound.SURFACE, room, BEDROOM), "a Mound room")
	assert_true(_mounds.order_edge(Vector2i(20, 21), 2, Mound.KIND_DOOR, Mound.COLOUR_OAK), "its door")
	_works.order_way_down(0, Vector2i(20, 20), Families.LADDER_HATCH, 0)
	_works.order_room(1, PackedInt32Array([22, 20, 23, 20, 22, 21, 23, 21]), KITCHEN)
	var door: Vector3i = Vector3i(20, 21, 2)
	assert_equal(_host.cut_off(PackedInt32Array(), [door]), "Kitchen (level 1), Bedroom (surface)", "both")
	assert_true(_mounds.order_edge(Vector2i(20, 20), 0, Mound.KIND_DOOR, Mound.COLOUR_OAK), "a second door")
	assert_equal(_host.cut_off(PackedInt32Array(), [door]), "", "the other door serves")
	assert_equal(_host.cut_off(PackedInt32Array([0, 20, 20]), []), "Kitchen (level 1)", "the hatch serves the Kitchen")


func test_a_resident_on_a_run_counts_at_its_ways_landing() -> void:
	"""Mutation H6: someone walking a burrow mouth's run is cut off with the way's landing."""
	_works.order_way_down(0, Vector2i(30, 2), Families.RAMP, 0)
	_below.append(["Basil", Vector3i(1, 30, 8)])
	assert_equal(_host.cut_off(PackedInt32Array([0, 30, 2]), []), "Basil", "named")
