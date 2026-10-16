extends "res://test/framework/test_case.gd"
## The pending doors and windows of Mound rooms (decision 2002; build_mound_edges.gd): rows, Undo's live flag, where one
## may stand and the refusals in words (BUILD-MOUND-020, -029, -030 and the proposals), removals, and the doors a Mound
## will have.

const MoundEdges := preload("res://scripts/ui/build_mound_edges.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")

var _edges: MoundEdges = null
## A 6 × 4 Mound room at (2, 2)-(7, 5), and the confirmed doors and windows (first edge -> kind) the host knows.
var _rooms: Dictionary = {}
var _confirmed: Dictionary = {}
var _listed: Array[Vector3i] = []


func before_each() -> void:
	"""The room, nothing confirmed, the store bound to them."""
	_rooms.clear()
	for z: int in range(2, 6):
		for x: int in range(2, 8):
			_rooms[Vector2i(x, z)] = true
	_confirmed.clear()
	_listed.clear()
	_edges = MoundEdges.new()
	_edges.bind_host(_is_room, _confirmed_at, _list_of)


func _list_of(kind: int) -> Array:
	"""The host's list reader: the confirmed ones of `kind`."""
	var out: Array = []
	for first: Vector3i in _confirmed:
		if int(_confirmed[first]) == kind:
			out.append(first)
	return out


func _is_room(level: int, cell: Vector2i) -> bool:
	"""The host's room reader: the fixture's room, on the Surface."""
	return level == Mound.SURFACE and _rooms.has(cell)


func _confirmed_at(_level: int, edge: Vector3i) -> Vector4i:
	"""The host's confirmed reader over `_confirmed` (each with its two or one edges)."""
	for first: Vector3i in _confirmed:
		var kind: int = _confirmed[first]
		for own: Vector3i in Mound.edges_of(kind, Mound.cell_of(first), first.z):
			if Mound.same_edge(own, edge):
				return Vector4i(kind, first.x, first.y, first.z)
	return MoundEdges.NONE


func _kind(judged: Array) -> int:
	"""A judgement's kind."""
	return int(judged[0])


func test_rows_their_reads_and_undos_live_flag() -> void:
	"""A row keeps its level, cell, side (wrapped), kind, colour and whether it removes; Undo clears it, Redo sets it."""
	var row: int = _edges.add(0, Vector2i(3, 2), 4, Mound.KIND_DOOR, 2, false)
	assert_equal([_edges.level_of(row), _edges.cell_of(row), _edges.side_of(row)], [0, Vector2i(3, 2), 0], "read back")
	assert_equal([_edges.kind_of(row), _edges.colour_of(row), _edges.is_removal(row)], [Mound.KIND_DOOR, 2, false],
		"kind, colour")
	assert_equal(_edges.edges_of(row), [Vector3i(3, 2, 0), Vector3i(4, 2, 0)] as Array[Vector3i], "its two edges")
	assert_true(_edges.is_live(row) and _edges.live_count() == 1 and _edges.count() == 1, "live")
	_edges.set_live(row, false)
	assert_false(_edges.is_live(row) or _edges.is_live(4) or _edges.is_live(-1), "undone; no other rows")
	assert_equal(_edges.live_count(), 0, "none live")
	_edges.add(0, Vector2i(3, 5), 2, Mound.KIND_WINDOW, 0, true)
	assert_true(_edges.is_removal(1), "a removal")
	_edges.clear()
	assert_equal(_edges.count(), 0, "cleared")


func test_row_at_finds_a_live_row_by_any_of_its_edges() -> void:
	"""A placement or (asked for) a removal, named from either side of the line; not a dead row nor another level."""
	_edges.add(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, 0, false)
	_edges.add(0, Vector2i(6, 5), 2, Mound.KIND_WINDOW, 0, true)
	assert_equal(_edges.row_at(0, Vector3i(4, 2, 0), false), 0, "the door's second edge")
	assert_equal(_edges.row_at(0, Vector3i(4, 1, 2), false), 0, "named from outside")
	assert_equal(_edges.row_at(0, Vector3i(6, 5, 2), false), -1, "a removal is not a placement")
	assert_equal(_edges.row_at(0, Vector3i(6, 5, 2), true), 1, "asked for, it is found")
	assert_equal(_edges.row_at(1, Vector3i(3, 2, 0), false), -1, "another level")
	_edges.set_live(0, false)
	assert_equal(_edges.row_at(0, Vector3i(3, 2, 0), false), -1, "undone")


func test_a_door_and_a_window_on_outer_edges_can_be_built() -> void:
	"""On the Surface, on outer edges: ✓."""
	assert_equal(_edges.judge(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, -1), [Validity.KIND_CAN_BUILD, ""], "a door")
	assert_equal(_kind(_edges.judge(0, Vector2i(7, 3), 1, Mound.KIND_WINDOW, -1)), Validity.KIND_CAN_BUILD, "a window")


func test_off_an_outer_edge_in_the_ruled_words() -> void:
	"""BUILD-MOUND-030 for the first edge (inside the room, or no room's), -029 when only a door's second fails."""
	var inside: Array = _edges.judge(0, Vector2i(3, 3), 0, Mound.KIND_WINDOW, -1)
	assert_equal(inside, [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_OFF_OUTER], "between two cells of the room")
	assert_equal(String(_edges.judge(0, Vector2i(20, 20), 0, Mound.KIND_DOOR, -1)[1]), Mound.TEXT_OFF_OUTER, "no room")
	var corner: Array = _edges.judge(0, Vector2i(7, 2), 0, Mound.KIND_DOOR, -1)
	assert_equal(corner, [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_DOOR_PAIR], "its second edge past the corner")
	assert_equal(String(_edges.judge(0, Vector2i(3, 2), 0, 9, -1)[1]), Mound.TEXT_OFF_OUTER, "no such kind")


func test_below_the_surface_a_window_has_no_hill_face() -> void:
	"""BUILD-MOUND-020: underground a window is refused in its words; a front door is no underground door."""
	assert_equal(_edges.judge(1, Vector2i(3, 2), 0, Mound.KIND_WINDOW, -1),
		[Validity.KIND_NOT_POSSIBLE, Mound.TEXT_NO_HILL_FACE], "a window on level 1")
	assert_equal(String(_edges.judge(2, Vector2i(3, 2), 0, Mound.KIND_DOOR, -1)[1]), Mound.TEXT_OFF_OUTER, "a door")


func test_an_edge_holding_one_is_taken() -> void:
	"""A pending or confirmed door or window on an edge refuses another there ("taken"); a door's second edge taken is
	-029; its own row never refuses it; a confirmed one under a pending removal frees the edge."""
	_edges.add(0, Vector2i(4, 2), 0, Mound.KIND_WINDOW, 0, false)
	assert_equal(String(_edges.judge(0, Vector2i(4, 2), 0, Mound.KIND_DOOR, -1)[1]), Mound.edge_taken(Mound.KIND_WINDOW),
		"the window's edge")
	assert_equal(String(_edges.judge(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, -1)[1]), Mound.TEXT_DOOR_PAIR,
		"a door whose second edge holds it")
	assert_equal(_kind(_edges.judge(0, Vector2i(4, 2), 0, Mound.KIND_WINDOW, 0)), Validity.KIND_CAN_BUILD, "itself")
	_confirmed[Vector3i(2, 4, 3)] = Mound.KIND_WINDOW
	assert_equal(String(_edges.judge(0, Vector2i(2, 4), 3, Mound.KIND_WINDOW, -1)[1]), Mound.edge_taken(Mound.KIND_WINDOW),
		"a confirmed window")
	_edges.add(0, Vector2i(2, 4), 3, Mound.KIND_WINDOW, 0, true)
	assert_equal(_kind(_edges.judge(0, Vector2i(2, 4), 3, Mound.KIND_WINDOW, -1)), Validity.KIND_CAN_BUILD,
		"removed: free again")


func test_a_doors_yard_must_be_clear_of_rooms() -> void:
	"""A door with a room in or beside its yard -- the yard, a cell past its foot, two cells either side -- is refused
	(that room's wall would open onto the cut); a room further off is fine."""
	_rooms[Vector2i(3, -2)] = true
	assert_equal(_edges.judge(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, -1),
		[Validity.KIND_NOT_POSSIBLE, Mound.TEXT_YARD_BLOCKED], "a room a cell past the yard's foot")
	assert_equal(_kind(_edges.judge(0, Vector2i(3, 2), 0, Mound.KIND_WINDOW, -1)), Validity.KIND_CAN_BUILD,
		"a window has no yard")
	_rooms.erase(Vector2i(3, -2))
	_rooms[Vector2i(3, -3)] = true
	assert_equal(_kind(_edges.judge(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, -1)), Validity.KIND_CAN_BUILD, "two past")
	_rooms[Vector2i(8, 1)] = true
	assert_equal(String(_edges.judge(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, -1)[1]), Mound.TEXT_YARD_BLOCKED,
		"two cells beside the yard")
	_rooms.erase(Vector2i(8, 1))
	_rooms[Vector2i(9, 1)] = true
	assert_equal(_kind(_edges.judge(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, -1)), Validity.KIND_CAN_BUILD, "three beside")


func test_a_window_beside_a_yard_or_facing_a_near_room_is_refused() -> void:
	"""A window within three cells of a yard's side is refused (the slope is cut there, and the garden stands there);
	so is one with another room within the berm beyond it (BUILD-MOUND-020: the hill never falls to its height)."""
	for x: int in range(8, 16):
		for z: int in range(2, 6):
			_rooms[Vector2i(x, z)] = true
	_edges.add(0, Vector2i(4, 2), 0, Mound.KIND_DOOR, 0, false)
	for x: int in [8, 9, 10]:
		assert_equal(String(_edges.judge(0, Vector2i(x, 2), 0, Mound.KIND_WINDOW, -1)[1]), Mound.TEXT_WINDOW_YARD,
			"%d cells beside the yard" % (x - 7))
	assert_equal(_kind(_edges.judge(0, Vector2i(11, 2), 0, Mound.KIND_WINDOW, -1)), Validity.KIND_CAN_BUILD, "four")
	_rooms[Vector2i(12, 7)] = true
	assert_equal(_edges.judge(0, Vector2i(12, 5), 2, Mound.KIND_WINDOW, -1),
		[Validity.KIND_NOT_POSSIBLE, Mound.TEXT_NO_HILL_FACE], "a room a cell past the window's first cell out")
	assert_equal(_kind(_edges.judge(0, Vector2i(13, 5), 2, Mound.KIND_WINDOW, -1)), Validity.KIND_CAN_BUILD, "beside it")


func test_a_window_never_faces_a_doors_yard() -> void:
	"""A window facing into a pending or confirmed door's yard is refused, and so is a door whose yard a window faces;
	beside the yard, or with the door taken away, it is fine."""
	_edges.add(0, Vector2i(4, 2), 0, Mound.KIND_DOOR, 0, false)
	assert_equal(_edges.judge(0, Vector2i(2, 2), 0, Mound.KIND_WINDOW, -1),
		[Validity.KIND_NOT_POSSIBLE, Mound.TEXT_WINDOW_YARD], "two cells along from the door: in its yard")
	assert_equal(_kind(_edges.judge(0, Vector2i(7, 3), 1, Mound.KIND_WINDOW, -1)), Validity.KIND_CAN_BUILD,
		"on another wall")
	_edges.set_live(0, false)
	assert_equal(_kind(_edges.judge(0, Vector2i(2, 2), 0, Mound.KIND_WINDOW, -1)), Validity.KIND_CAN_BUILD,
		"the door undone")
	_edges.add(0, Vector2i(7, 2), 0, Mound.KIND_WINDOW, 0, false)
	assert_equal(String(_edges.judge(0, Vector2i(4, 2), 0, Mound.KIND_DOOR, -1)[1]), Mound.TEXT_WINDOW_YARD,
		"a door whose yard a pending window faces")
	_confirmed[Vector3i(3, 5, 2)] = Mound.KIND_DOOR
	assert_equal(String(_edges.judge(0, Vector2i(6, 5), 2, Mound.KIND_WINDOW, -1)[1]), Mound.TEXT_WINDOW_YARD,
		"a confirmed door's yard")
	_edges.add(0, Vector2i(3, 5), 2, Mound.KIND_DOOR, 0, true)
	assert_equal(_kind(_edges.judge(0, Vector2i(6, 5), 2, Mound.KIND_WINDOW, -1)), Validity.KIND_CAN_BUILD,
		"that door being removed")
	assert_equal(_edges.placed(0, Mound.KIND_DOOR, -1), [] as Array[Vector3i], "no door will stand")
	assert_equal(_edges.placed(0, Mound.KIND_WINDOW, -1), [Vector3i(7, 2, 0)] as Array[Vector3i], "one window")
	assert_equal(_edges.placed(1, Mound.KIND_WINDOW, -1), [] as Array[Vector3i], "none on level 1")


func test_confirmed_at_reads_the_host_less_the_removals() -> void:
	"""The host's door or window on an edge, unless a pending removal takes it; none with no host."""
	_confirmed[Vector3i(3, 2, 0)] = Mound.KIND_DOOR
	assert_equal(_edges.confirmed_at(0, Vector3i(4, 2, 0)), Vector4i(Mound.KIND_DOOR, 3, 2, 0), "by its second edge")
	assert_false(_edges.removed(0, Vector3i(3, 2, 0)), "not removed")
	_edges.add(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, 0, true)
	assert_true(_edges.removed(0, Vector3i(3, 2, 0)), "a removal pending")
	assert_equal(_edges.confirmed_at(0, Vector3i(4, 2, 0)), MoundEdges.NONE, "taken away")
	var bare: MoundEdges = MoundEdges.new()
	assert_equal(bare.confirmed_at(0, Vector3i(3, 2, 0)), MoundEdges.NONE, "no host")
	assert_equal(String(bare.judge(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, -1)[1]), Mound.TEXT_OFF_OUTER,
		"no host: no room")


func test_a_rows_judgement_where_it_stands_now() -> void:
	"""A placement is judged again when read; a removal is ✓ while its door or window stands."""
	var row: int = _edges.add(0, Vector2i(5, 2), 0, Mound.KIND_WINDOW, 0, false)
	assert_equal(_kind(_edges.row_judgement(row)), Validity.KIND_CAN_BUILD, "on its outer edge")
	_rooms[Vector2i(5, 1)] = true
	assert_equal(_edges.row_judgement(row), [Validity.KIND_NOT_POSSIBLE, Mound.TEXT_OFF_OUTER], "a room now beyond it")
	var removal: int = _edges.add(0, Vector2i(2, 3), 3, Mound.KIND_WINDOW, 0, true)
	assert_equal(_kind(_edges.row_judgement(removal)), Validity.KIND_NOT_POSSIBLE, "nothing there to remove")
	_confirmed[Vector3i(2, 3, 3)] = Mound.KIND_WINDOW
	assert_equal(_kind(_edges.row_judgement(removal)), Validity.KIND_CAN_BUILD, "its window stands")


func test_the_doors_a_mound_will_have() -> void:
	"""BUILD-MOUND-012: pending doors that can be built, on the level asked; not windows, removals or refused doors."""
	_edges.add(0, Vector2i(3, 2), 0, Mound.KIND_DOOR, 0, false)
	_edges.add(0, Vector2i(6, 5), 2, Mound.KIND_WINDOW, 0, false)
	_edges.add(0, Vector2i(3, 5), 2, Mound.KIND_DOOR, 0, true)
	_edges.add(0, Vector2i(3, 3), 0, Mound.KIND_DOOR, 0, false)
	var out: PackedInt32Array = PackedInt32Array([9, 9])
	_edges.doors_into(0, out)
	assert_equal(out, PackedInt32Array([3, 2]), "the one door that can be built")
	_edges.doors_into(1, out)
	assert_true(out.is_empty(), "none on level 1")
