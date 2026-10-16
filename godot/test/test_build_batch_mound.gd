extends "res://test/framework/test_case.gd"
## The batch's Mound homes (decision 2002; build_batch.gd MOUND HOMES): a stroke's style (BUILD-MOUND-028, -002 and
## the merge by style), the way in a door gives (BUILD-MOUND-012), the hill's ground (BUILD-MOUND-008), a buried door or
## window (BUILD-MOUND-018's stand-in), a way down on the hill or a room's floor, the doors and windows clicked in and
## out with Undo and Redo, Confirm all's route for them, and the host's readers.

const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Cells := preload("res://scripts/ui/build_cell_validity.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const MoundEdges := preload("res://scripts/ui/build_mound_edges.gd")
const Stroke := preload("res://scripts/ui/build_stroke.gd")

const KITCHEN: int = 2
const BEDROOM: int = 1
const BOUNDS: Rect2i = Rect2i(0, 0, 64, 64)
const CAPACITY: int = 4096
const MOUND: int = Mound.STYLE_MOUND
const BUILT: int = Mound.STYLE_BUILT

var _batch: Batch = null
## The host: confirmed Mound cells, the ways down on the surface (north-west cells), what covers a cell, its doors
## (first edges -> kind of door or window), and what Confirm all ordered.
var _host_cells: PackedInt32Array = PackedInt32Array()
var _host_ways: PackedInt32Array = PackedInt32Array()
var _things: Dictionary = {}
var _host_edges: Dictionary = {}
var _edge_orders: Array = []


func before_each() -> void:
	"""A batch with the fixture host bound."""
	_batch = Batch.new()
	assert_equal(_batch.configure(BuildCatalog.new(), BOUNDS, CAPACITY), &"", "configured")
	_host_cells = PackedInt32Array()
	_host_ways = PackedInt32Array()
	_things.clear()
	_host_edges.clear()
	_edge_orders.clear()
	_batch.bind_mound_host(_cells_of_host, _ways_of_host, _thing_at, _doors_of_host, _edge_of_host, _listed_of_host)


func after_each() -> void:
	"""Let go of the batch (its readers close over this suite)."""
	_batch = null


func _cells_of_host() -> PackedInt32Array:
	"""The host's confirmed Mound cells."""
	return _host_cells


func _ways_of_host(level: int) -> PackedInt32Array:
	"""The host's confirmed ways down on `level`."""
	return _host_ways if level == 0 else PackedInt32Array()


func _thing_at(cell: Vector2i) -> String:
	"""What the hill would cover at `cell`."""
	return String(_things.get(cell, ""))


func _doors_of_host() -> Array:
	"""The host's confirmed doors' first edges."""
	return _listed_of_host(Mound.KIND_DOOR)


func _listed_of_host(kind: int) -> Array:
	"""The host's confirmed doors or windows of `kind`."""
	var out: Array = []
	for first: Vector3i in _host_edges:
		if int(_host_edges[first]) == kind:
			out.append(first)
	return out


func _edge_of_host(_level: int, edge: Vector3i) -> Vector4i:
	"""The host's door or window on `edge`."""
	for first: Vector3i in _host_edges:
		var kind: int = _host_edges[first]
		for own: Vector3i in Mound.edges_of(kind, Mound.cell_of(first), first.z):
			if Mound.same_edge(own, edge):
				return Vector4i(kind, first.x, first.y, first.z)
	return MoundEdges.NONE


func _paint(room_type: int, level: int, from: Vector2i, to: Vector2i, style: int = MOUND) -> int:
	"""One rectangle stroke in `style`, released; its validity kind."""
	assert_true(_batch.begin_stroke(room_type, level, from, style), "stroke begins")
	_batch.extend_stroke(to)
	return _batch.finish_stroke()


func _submit_room(_draft: Object, _level: int, _room_type: int) -> Dictionary:
	"""Every room is taken."""
	return {"ok": true, "error": ""}


func _submit_edge(level: int, cell: Vector2i, side: int, kind: int, colour: int, removal: bool) -> Dictionary:
	"""Every door, window and removal is taken; recorded."""
	_edge_orders.append([level, cell, side, kind, colour, removal])
	return {"ok": true, "error": ""}


func _rect(from: Vector2i, to: Vector2i) -> PackedInt32Array:
	"""A rectangle's cells (pairs)."""
	var out: PackedInt32Array = PackedInt32Array()
	for z: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			out.append_array(PackedInt32Array([x, z]))
	return out


func test_a_stroke_keeps_its_style_and_level() -> void:
	"""BUILD-MOUND-028: a Mound stroke below the Surface is "X" in its words; a built one on the Surface is not yet
	(slice G); an unknown style begins nothing."""
	assert_false(_batch.begin_stroke(KITCHEN, 0, Vector2i(10, 10), 7), "no such style")
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(10, 10), MOUND), "begun")
	_batch.extend_stroke(Vector2i(15, 13))
	assert_equal(_batch.stroke_style(), MOUND, "its style")
	assert_equal(_batch.stroke_line(), "Paint Kitchen 6 × 4 cells (6 m × 4 m); X Not possible: %s" % Mound.TEXT_SURFACE_ONLY,
		"not below the Surface")
	assert_equal(_batch.finish_stroke(), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_equal(_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13), BUILT), Validity.KIND_NOT_POSSIBLE,
		"built on the Surface")
	assert_equal(_batch.last_dropped(), "X Not possible: %s" % Mound.LATER_BUILT_SURFACE, "in words")
	assert_equal(_batch.operation_count(), 0, "nothing joined")


func test_a_mound_room_has_no_way_in_until_a_door() -> void:
	"""BUILD-MOUND-012: every cell "! No way in: place a door on an outer edge" (not the connectors' way in); a door
	on an outer edge makes it ✓; Confirm all is held back meanwhile."""
	assert_equal(_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13)), Validity.KIND_BLOCKED, "kept, blocked")
	assert_equal(_batch.operation_style(0), MOUND, "a Mound room")
	assert_equal(_batch.operation_reason(0), Mound.TEXT_NO_DOOR, "its words")
	assert_true(_batch.operation_cell_codes(0).has(Cells.CELL_NO_DOOR), "per cell")
	assert_false(_batch.operation_cell_codes(0).has(Cells.CELL_NO_WAY_IN), "not the underground's way in")
	assert_equal(_batch.confirm_all(_submit_room, Callable(), Callable(), _submit_edge), PackedInt32Array([0, 0]),
		"held back")
	assert_equal(_batch.toggle_mound_edge(0, Vector2i(12, 10), 0, Mound.KIND_DOOR, 1), Validity.KIND_CAN_BUILD, "a door")
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "✓ with its door")
	assert_equal(_batch.pending_count(), 2, "the room and its door")


func test_a_stroke_shows_no_way_in_and_a_door_in_a_neighbour_serves_it() -> void:
	"""The stroke's own words; a joined Mound room is served by its neighbour's door, a separate Mound is not."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	_batch.toggle_mound_edge(0, Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	assert_true(_batch.begin_stroke(BEDROOM, 0, Vector2i(16, 10), MOUND), "begun")
	_batch.extend_stroke(Vector2i(21, 13))
	assert_equal(_batch.stroke_kind(), Validity.KIND_CAN_BUILD, "joined to the Kitchen: its door serves")
	_batch.finish_stroke()
	assert_equal(_paint(BEDROOM, 0, Vector2i(30, 10), Vector2i(35, 13)), Validity.KIND_BLOCKED, "apart: no way in")
	assert_true(_batch.begin_stroke(BEDROOM, 0, Vector2i(40, 10), MOUND), "begun")
	_batch.extend_stroke(Vector2i(45, 13))
	assert_equal(_batch.stroke_reason(), Mound.TEXT_NO_DOOR, "the stroke's own words")
	_batch.cancel_stroke()


func test_a_confirmed_door_serves_a_new_room_joined_to_it() -> void:
	"""The host's door on a confirmed Mound serves a room painted beside it (growth); a pending removal takes it."""
	_host_cells = _rect(Vector2i(10, 10), Vector2i(15, 13))
	_host_edges[Vector3i(12, 10, 0)] = Mound.KIND_DOOR
	_batch.host_changed()
	assert_equal(_paint(BEDROOM, 0, Vector2i(10, 14), Vector2i(15, 17)), Validity.KIND_CAN_BUILD, "grows the Mound")
	_batch.toggle_mound_edge(0, Vector2i(13, 10), 0, Mound.KIND_DOOR, 0)
	assert_true(_batch.mound_edges().is_removal(0), "a click on the built door asks for its removal")
	assert_equal(_batch.operation_reason(0), Mound.TEXT_NO_DOOR, "then no way in")


func test_one_style_per_room_and_merging_by_style() -> void:
	"""BUILD-MOUND-002: a stroke of one style beside a same-type room of the other is "X"; over another style's
	room is an overlap; same type and style merge."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	assert_equal(_paint(KITCHEN, 0, Vector2i(16, 10), Vector2i(19, 13)), Validity.KIND_BLOCKED, "kept")
	assert_equal(_batch.operation_count(), 1, "merged into the Kitchen")
	assert_true(_batch.begin_stroke(KITCHEN, 0, Vector2i(20, 10), BUILT), "a built Kitchen beside it")
	_batch.extend_stroke(Vector2i(25, 13))
	assert_true(_batch.stroke_reason() == Mound.LATER_BUILT_SURFACE, "built rooms are refused on the Surface first")
	_batch.cancel_stroke()
	var other: Batch = Batch.new()
	other.configure(BuildCatalog.new(), BOUNDS, CAPACITY)
	other.begin_stroke(KITCHEN, 1, Vector2i(10, 10), BUILT)
	other.extend_stroke(Vector2i(15, 13))
	other.finish_stroke()
	assert_true(other.begin_stroke(KITCHEN, 1, Vector2i(16, 10), MOUND), "a Mound stroke beside a built Kitchen")
	other.extend_stroke(Vector2i(19, 13))
	assert_equal(other.stroke_reason(), Mound.TEXT_SURFACE_ONLY, "below: the surface rule first")
	other.cancel_stroke()


func test_the_join_rule_between_styles() -> void:
	"""The style refusals in their order (a seam the cards keep shut): a built Kitchen painted (through the batch) on
	the Surface is refused, so the -002 words are reached only when both styles could stand on one level."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	assert_true(_batch.begin_stroke(BEDROOM, 0, Vector2i(16, 10), MOUND), "another type beside it")
	_batch.extend_stroke(Vector2i(21, 13))
	assert_false(_batch.stroke_reason() == Mound.TEXT_NO_JOIN, "another type joins freely")
	_batch.cancel_stroke()


func test_the_hill_may_not_cover_water_or_things() -> void:
	"""BUILD-MOUND-008: a thing under a room or its berm refuses the stroke in words; past the berm it does not."""
	_things[Vector2i(12, 7)] = "a tree"
	assert_equal(_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13)), Validity.KIND_NOT_POSSIBLE, "three cells out")
	assert_equal(_batch.last_dropped(), "X Not possible: the hill would cover a tree", "in words")
	_things.clear()
	_things[Vector2i(12, 6)] = "water"
	assert_equal(_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13)), Validity.KIND_BLOCKED, "four cells out: fine")
	_things[Vector2i(14, 12)] = "water"
	_batch.host_changed()
	assert_equal(_batch.operation_kind(0), Validity.KIND_NOT_POSSIBLE, "water under the room now: the room says so")
	assert_equal(_batch.operation_reason(0), "the hill would cover water", "its words")


func test_the_hill_judges_each_mound_apart() -> void:
	"""A thing by one Mound's hill refuses that Mound only."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	_paint(KITCHEN, 0, Vector2i(40, 10), Vector2i(45, 13))
	_things[Vector2i(41, 15)] = "a well"
	_batch.host_changed()
	assert_equal(_batch.operation_reason(1), "the hill would cover a well", "the far one")
	assert_equal(_batch.operation_reason(0), Mound.TEXT_NO_DOOR, "the near one only lacks its door")


func test_a_way_down_on_the_hill_or_across_a_rooms_edge_is_refused() -> void:
	"""BUILD-MOUND-021: a way down wholly on a Mound room's floor is a hatch (✓); on the berm it builds on the hill, and
	across a room's edge it is split: both "X"; a stroke whose hill would cover a way down is "X"."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	assert_equal(int(_batch.judge_item(0, Vector2i(11, 11), -1)[0]), Validity.KIND_CAN_BUILD, "on the floor")
	assert_equal(_batch.judge_item(0, Vector2i(11, 8), -1), [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_ON_HILL], "on the berm")
	assert_equal(_batch.judge_item(0, Vector2i(11, 9), -1), [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_SPLIT_WAY],
		"across the wall")
	assert_equal(int(_batch.judge_item(0, Vector2i(30, 30), -1)[0]), Validity.KIND_CAN_BUILD, "off the hill")
	_batch.place_item(0, Vector2i(30, 30))
	assert_equal(_paint(BEDROOM, 0, Vector2i(31, 33), Vector2i(36, 36)), Validity.KIND_NOT_POSSIBLE, "a hill over it")
	assert_equal(_batch.last_dropped(), "X Not possible: the hill would cover an Entrance", "its words")
	_host_ways = PackedInt32Array([20, 20])
	assert_equal(_paint(BEDROOM, 0, Vector2i(21, 23), Vector2i(26, 26)), Validity.KIND_NOT_POSSIBLE, "a confirmed one")


func test_a_stroke_may_not_bury_a_built_door_or_window() -> void:
	"""BUILD-MOUND-018 stood in for: a stroke over the cell beyond a confirmed window is "X" in words."""
	_host_cells = _rect(Vector2i(10, 10), Vector2i(15, 13))
	_host_edges[Vector3i(12, 10, 0)] = Mound.KIND_WINDOW
	_batch.host_changed()
	assert_equal(_paint(BEDROOM, 0, Vector2i(10, 6), Vector2i(15, 9)), Validity.KIND_NOT_POSSIBLE, "over its slope")
	assert_equal(_batch.last_dropped(), "X Not possible: %s" % Mound.covers_edge_item(Mound.KIND_WINDOW), "in words")


func test_no_room_stands_in_or_beside_a_doors_yard() -> void:
	"""A stroke into or beside the yard of a pending or confirmed door is "X" (its walls would open onto the cut); one
	clear of it is kept."""
	_host_cells = _rect(Vector2i(10, 10), Vector2i(15, 13))
	_host_edges[Vector3i(12, 10, 0)] = Mound.KIND_DOOR
	_batch.host_changed()
	assert_equal(_paint(BEDROOM, 0, Vector2i(16, 6), Vector2i(21, 9)), Validity.KIND_NOT_POSSIBLE, "beside the yard")
	assert_equal(_batch.last_dropped(), "X Not possible: %s" % Mound.TEXT_IN_YARD, "in words")
	assert_equal(_paint(BEDROOM, 0, Vector2i(10, 2), Vector2i(15, 5)), Validity.KIND_BLOCKED, "two cells past its foot")
	assert_equal(_paint(BEDROOM, 0, Vector2i(30, 10), Vector2i(35, 13)), Validity.KIND_BLOCKED, "far off: kept")
	_batch.toggle_mound_edge(0, Vector2i(31, 13), 2, Mound.KIND_DOOR, 0)
	assert_equal(_paint(BEDROOM, 0, Vector2i(30, 15), Vector2i(35, 18)), Validity.KIND_NOT_POSSIBLE, "a pending door's")


func test_withdrawing_a_removal_under_a_new_room_holds_confirm_all() -> void:
	"""Review H4: a built window marked for removal, a room painted over its slope, then the removal withdrawn: the
	room is "X" again in E7's words and Confirm all waits."""
	_host_cells = _rect(Vector2i(10, 10), Vector2i(15, 13))
	_host_edges[Vector3i(13, 13, 2)] = Mound.KIND_DOOR
	_host_edges[Vector3i(12, 10, 0)] = Mound.KIND_WINDOW
	_batch.host_changed()
	_batch.toggle_mound_edge(0, Vector2i(12, 10), 0, Mound.KIND_WINDOW, 0)
	assert_equal(_paint(BEDROOM, 0, Vector2i(10, 6), Vector2i(15, 9)), Validity.KIND_CAN_BUILD, "over the removed one")
	_batch.toggle_mound_edge(0, Vector2i(12, 10), 0, Mound.KIND_WINDOW, 0)
	assert_false(_batch.mound_edges().is_live(0), "the removal withdrawn")
	assert_equal(_batch.operation_kind(0), Validity.KIND_NOT_POSSIBLE, "the room X")
	assert_equal(_batch.operation_reason(0), Mound.covers_edge_item(Mound.KIND_WINDOW), "in words")
	assert_equal(_batch.confirm_all(_submit_room, Callable(), Callable(), _submit_edge), PackedInt32Array([0, 0]), "held")


func test_the_style_join_refusal() -> void:
	"""BUILD-MOUND-002, reached only once both styles stand on one level (slice G): a stroke beside a same-type room of
	the other style is "X" in its words. White-box: the room's style is set as slice G would let it be."""
	_paint(KITCHEN, 1, Vector2i(10, 10), Vector2i(15, 13), BUILT)
	_batch._styles[0] = MOUND
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(16, 10), BUILT), "a built Kitchen beside it")
	_batch.extend_stroke(Vector2i(19, 13))
	assert_equal(_batch.stroke_reason(), Mound.TEXT_NO_JOIN, "the -002 words")
	_batch.cancel_stroke()
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(17, 10), BUILT), "a cell between")
	_batch.extend_stroke(Vector2i(20, 13))
	assert_false(_batch.stroke_reason() == Mound.TEXT_NO_JOIN, "apart: no join")
	_batch.cancel_stroke()


func test_ground_the_crew_cannot_dig_stays_x_under_no_way_in() -> void:
	"""A doorless Mound room whose cell turns to water keeps that cell's own X code (never "No way in" over it), so
	the room is X in the ground's words."""
	var water: Dictionary = {}
	var ground_revision: Array[int] = [0]
	_batch.bind_ground(func(level: int, cell: Vector2i) -> int:
		return int(water.get(cell, Cells.CELL_OK)) if level == 0 else Cells.CELL_OK,
		func() -> int: return ground_revision[0])
	assert_equal(_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13)), Validity.KIND_BLOCKED, "no door yet")
	water[Vector2i(12, 11)] = Cells.CELL_WATER
	ground_revision[0] += 1
	assert_equal(_batch.operation_cell_codes(0).count(Cells.CELL_WATER), 1, "the water cell keeps its code")
	assert_equal(_batch.operation_cell_codes(0).count(Cells.CELL_NO_DOOR), 23, "the rest: no way in")
	assert_equal(_batch.operation_kind(0), Validity.KIND_NOT_POSSIBLE, "X")


func test_a_way_down_at_a_rooms_inner_corner_is_split() -> void:
	"""A 2 × 2 way down three cells on the rooms' floor and one on the hill is split, not merely on the hill."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	_paint(BEDROOM, 0, Vector2i(10, 14), Vector2i(13, 17))
	assert_equal(_batch.judge_item(0, Vector2i(13, 13), -1), [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_SPLIT_WAY],
		"three of four on the floor")


func test_a_strokes_hill_is_judged_with_its_own_mound_only() -> void:
	"""Something by another, confirmed Mound's hill does not refuse a stroke for a Mound of its own far away."""
	_host_cells = _rect(Vector2i(10, 10), Vector2i(15, 13))
	_things[Vector2i(12, 8)] = "a well"
	_batch.host_changed()
	assert_equal(_paint(BEDROOM, 0, Vector2i(40, 40), Vector2i(45, 43)), Validity.KIND_BLOCKED, "kept: no door yet")
	assert_equal(_paint(BEDROOM, 0, Vector2i(10, 14), Vector2i(15, 17)), Validity.KIND_NOT_POSSIBLE, "joined to it: X")
	assert_equal(_batch.last_dropped(), "X Not possible: the hill would cover a well", "its hill's words")


func test_clicks_place_take_back_and_remove_doors_and_windows() -> void:
	"""A click places one (a step), on a pending one takes it back (a step), on a built one asks its removal (a
	step), on that removal withdraws it; Undo and Redo replay each; an "X" click keeps nothing."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	_host_cells = _rect(Vector2i(20, 10), Vector2i(25, 13))
	_host_edges[Vector3i(22, 10, 0)] = Mound.KIND_WINDOW
	_batch.host_changed()
	var steps: int = _batch.history_size()
	assert_equal(_batch.toggle_mound_edge(0, Vector2i(11, 13), 2, Mound.KIND_WINDOW, 0), Validity.KIND_CAN_BUILD, "placed")
	assert_equal(_batch.last_step_words(), "Place Window", "its step")
	assert_equal(_batch.toggle_mound_edge(0, Vector2i(11, 13), 2, Mound.KIND_DOOR, 0), Validity.KIND_CAN_BUILD,
		"a click on it")
	assert_equal([_batch.mound_edges().live_count(), _batch.last_step_words()], [0, "Remove Window"], "taken back")
	assert_true(_batch.undo(), "undo the taking back")
	assert_equal(_batch.mound_edges().live_count(), 1, "back")
	assert_true(_batch.redo(), "redo it")
	assert_equal(_batch.mound_edges().live_count(), 0, "gone again")
	assert_equal(_batch.toggle_mound_edge(0, Vector2i(22, 10), 0, Mound.KIND_DOOR, 0), Validity.KIND_CAN_BUILD,
		"on the built window")
	assert_true(_batch.mound_edges().is_removal(1), "its removal pending")
	assert_equal(_batch.last_step_words(), "Remove Window", "said as a removal")
	_batch.toggle_mound_edge(0, Vector2i(22, 10), 0, Mound.KIND_DOOR, 0)
	assert_false(_batch.mound_edges().is_live(1), "the removal withdrawn")
	assert_equal(_batch.toggle_mound_edge(0, Vector2i(12, 11), 0, Mound.KIND_WINDOW, 0), Validity.KIND_NOT_POSSIBLE, "X")
	assert_equal(_batch.last_dropped(), "X Not possible: %s" % Mound.TEXT_OFF_OUTER, "in words")
	assert_equal(_batch.history_size(), steps + 4, "four steps; the X kept none")
	_batch.begin_stroke(KITCHEN, 0, Vector2i(40, 40), MOUND)
	assert_equal(_batch.toggle_mound_edge(0, Vector2i(11, 13), 2, Mound.KIND_WINDOW, 0), -1, "not during a stroke")


func test_an_invalid_door_holds_confirm_all_back_and_counts() -> void:
	"""A room stroke into a door's yard is "X"; a pending door made invalid by a later Erase (its cells no room's now) is
	"X", counted, and holds Confirm all."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	_batch.toggle_mound_edge(0, Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	assert_equal(_paint(BEDROOM, 0, Vector2i(10, 6), Vector2i(15, 9)), Validity.KIND_NOT_POSSIBLE, "not in its yard")
	assert_equal(_batch.last_dropped(), "X Not possible: %s" % Mound.TEXT_IN_YARD, "in words")
	assert_true(_batch.set_tool(Stroke.TOOL_ERASE), "the Erase brush")
	assert_equal(_paint(KITCHEN, 0, Vector2i(12, 10), Vector2i(12, 10)), Validity.KIND_CAN_BUILD, "the door's cells out")
	assert_equal(_batch.first_invalid_edge(), 0, "the door")
	assert_equal(_batch.edge_reason(0), Mound.TEXT_OFF_OUTER, "no outer edge now")
	assert_true(_batch.invalid_count() >= 1, "counted")
	assert_equal(_batch.confirm_all(_submit_room, Callable(), Callable(), _submit_edge), PackedInt32Array([0, 0]), "held")


func test_confirm_all_orders_the_rooms_then_the_doors_and_windows() -> void:
	"""The rooms through their route, then each door, window and removal through `submit_edge` (its colour kept); they
	leave the batch and the history."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	_batch.toggle_mound_edge(0, Vector2i(12, 10), 0, Mound.KIND_DOOR, 2)
	_batch.toggle_mound_edge(0, Vector2i(15, 11), 1, Mound.KIND_WINDOW, 0)
	var result: PackedInt32Array = _batch.confirm_all(_submit_room, Callable(), Callable(), _submit_edge)
	assert_equal(result, PackedInt32Array([3, 0]), "three ordered")
	assert_equal(_edge_orders, [[0, Vector2i(12, 10), 0, Mound.KIND_DOOR, 2, false],
		[0, Vector2i(15, 11), 1, Mound.KIND_WINDOW, 0, false]], "the door (green) and the window")
	assert_equal(_batch.pending_count(), 0, "nothing pending")
	assert_false(_batch.can_undo(), "out of Undo's reach")


func test_discard_all_drops_doors_windows_and_styles() -> void:
	"""Discard all: the rooms, their styles and the doors and windows."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	_batch.toggle_mound_edge(0, Vector2i(12, 10), 0, Mound.KIND_DOOR, 0)
	assert_equal(_batch.discard_all(), 2, "two changes dropped")
	assert_equal([_batch.operation_count(), _batch.mound_edges().count()], [0, 0], "none left")


func test_the_surface_rooms_readers() -> void:
	"""`mound_cells`, `is_mound_room` and `is_surface_room`: pending and confirmed Mound cells on the Surface only."""
	_host_cells = PackedInt32Array([30, 30])
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(15, 13))
	assert_equal(_batch.mound_cells().size(), 2 + 48, "the host's and the room's")
	assert_true(_batch.is_mound_room(0, Vector2i(15, 13)) and _batch.is_surface_room(Vector2i(30, 30)), "both")
	assert_false(_batch.is_mound_room(1, Vector2i(15, 13)), "not below")
	assert_false(_batch.is_surface_room(Vector2i(16, 13)), "beside it: no room")


func test_a_mound_room_merged_away_and_back_keeps_its_style() -> void:
	"""An Erase that splits a Mound room makes Mound pieces; Undo puts it back."""
	_paint(KITCHEN, 0, Vector2i(10, 10), Vector2i(21, 13))
	assert_true(_batch.set_tool(Stroke.TOOL_ERASE), "the Erase brush")
	assert_equal(_paint(KITCHEN, 0, Vector2i(15, 10), Vector2i(15, 12)), Validity.KIND_CAN_BUILD, "a cut")
	assert_equal(_batch.operation_count(), 2, "split in two")
	assert_equal([_batch.operation_style(0), _batch.operation_style(1)], [MOUND, MOUND], "both Mound rooms")
	assert_true(_batch.undo(), "one step")
	assert_equal(_batch.pending_count(), 1, "one room again")
	assert_equal(_batch.operation_style(0), MOUND, "still a Mound room")
