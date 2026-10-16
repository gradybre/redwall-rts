extends "res://test/framework/test_case.gd"
## The hill's shape (decision 2002; demo_build_mound_field.gd): the ruled cover over every room, the wall never open,
## nothing past the berm, every room at the hill's edge, the hill only ever growing as rooms are added, the yard cut to
## the ground, a window's place on the slope at the wall's top metre, and the field's helpers.

const Field := preload("res://demo/build_panel/demo_build_mound_field.gd")
const Mound := preload("res://scripts/ui/build_mound.gd")

const DATUM: Vector2 = Vector2(100.0, 200.0)
## A sample step (m) fine enough to see a ripple, coarse enough to stay quick.
const STEP: float = 0.25

## A 6 × 4 Kitchen at (10, 10)-(15, 13) and a 4 × 4 room joined east at (16, 10)-(19, 13); the door on the north wall
## at (12, 10)-(13, 10).
var _field: Field = null
var _door: Vector3i = Vector3i(12, 10, 0)


func before_each() -> void:
	"""The two rooms and their door's yard."""
	_field = _made(_rect(Vector2i(10, 10), Vector2i(19, 13)), [_door] as Array[Vector3i])


static func _made(rooms: PackedInt32Array, doors: Array[Vector3i]) -> Field:
	"""A field set up over `rooms` and `doors` at DATUM."""
	var field: Field = Field.new()
	field.setup(rooms, doors, DATUM)
	return field


static func _rect(from: Vector2i, to: Vector2i) -> PackedInt32Array:
	"""A rectangle's cells (pairs, row by row)."""
	var out: PackedInt32Array = PackedInt32Array()
	for z: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			out.append_array(PackedInt32Array([x, z]))
	return out


func _at(cell_space: Vector2) -> Vector2:
	"""A cell-space point in world metres."""
	return cell_space + DATUM


func _samples(box: Rect2) -> PackedVector2Array:
	"""Points (cell space) every STEP across `box`, off the exact cell lines."""
	var out: PackedVector2Array = PackedVector2Array()
	var z: float = box.position.y + STEP * 0.5
	while z < box.end.y:
		var x: float = box.position.x + STEP * 0.5
		while x < box.end.x:
			out.append(Vector2(x, z))
			x += STEP
		z += STEP
	return out


func test_the_ruled_cover_lies_over_every_room() -> void:
	"""BUILD-MOUND-004: over every room point the hill is the wall's top and a metre more (or the crown above it); the
	turf over a door's eave is the one place it comes lower (a PROPOSAL, decision 2002)."""
	var least: float = INF
	var eave: int = 0
	for q: Vector2 in _samples(Rect2(10.0, 10.0, 10.0, 4.0)):
		if _field.in_eave(_at(q)):
			eave += 1
			continue
		least = minf(least, _field.height_m(_at(q)))
	assert_true(least >= Field.ROOM_TOP_M + Field.COVER_M - 0.0001, "never under 5 m: %f" % least)
	assert_true(eave > 0 and eave < 6 * 5 * 4 * 2, "the eave: a strip behind the door's front (%d samples)" % eave)
	var crown: float = _field.height_m(_at(Vector2(15.0, 12.0)))
	assert_true(crown > Field.ROOM_TOP_M + Field.COVER_M, "a crown rises inside")


func test_the_wall_is_never_open() -> void:
	"""P-2001-4: just outside every outer wall, but the door's yard, the hill stands above the wall's top."""
	var outer: Array[Vector3i] = []
	Mound.outer_edges_into(_rect(Vector2i(10, 10), Vector2i(19, 13)), _field.is_room, outer)
	var yard: Dictionary = Mound.set_of(Mound.yard_cells(Mound.cell_of(_door), _door.z))
	var checked: int = 0
	for edge: Vector3i in outer:
		if yard.has(Mound.outside_of(edge)):
			continue
		var out: Vector2 = Vector2(Mound.step_of(edge.z))
		for out_m: float in [0.01, 0.5, 1.0]:
			var q: Vector2 = Field.edge_middle(edge) + out * out_m
			assert_true(_field.height_m(_at(q)) > Field.ROOM_TOP_M, "edge %s, %f m out" % [edge, out_m])
			checked += 1
	assert_equal(checked, (10 + 10 + 4 + 4 - 6) * 3, "every outer edge but the six the yard faces")


func test_nothing_lies_past_the_berm_and_every_room_is_at_the_hills_edge() -> void:
	"""P-2001-4 (a), W13: the shoulder at the wall's foot, the ground three metres out, nothing beyond."""
	assert_true(is_equal_approx(_field.height_m(_at(Vector2(15.0, 14.2))), Field.ROOM_TOP_M + Field.COVER_M),
		"the shoulder, just past the south wall")
	assert_equal(_field.height_m(_at(Vector2(15.0, 17.0))), 0.0, "three metres out: the ground")
	assert_equal(_field.height_m(_at(Vector2(7.0, 12.0))), 0.0, "three metres west")
	assert_equal(_field.height_m(_at(Vector2(40.0, 40.0))), 0.0, "far off")
	for q: Vector2 in _samples(Rect2(4.0, 4.0, 22.0, 16.0)):
		if _field.room_distance(_at(q)) >= Field.BERM_M:
			assert_equal(_field.height_m(_at(q)), 0.0, "past the berm at %s" % q)
	assert_true(_field.height_m(_at(Vector2(15.0, 15.5))) < _field.height_m(_at(Vector2(15.0, 14.5))), "rolling down")


func test_the_hill_only_grows_as_rooms_are_added() -> void:
	"""BUILD-MOUND-015: a room joined on (the same door) never lowers the hill anywhere."""
	var grown: Field = _made(_rect(Vector2i(10, 10), Vector2i(19, 13)) + _rect(Vector2i(12, 14), Vector2i(15, 21)),
		[_door] as Array[Vector3i])
	var rose: int = 0
	for q: Vector2 in _samples(Rect2(4.0, 4.0, 22.0, 22.0)):
		var before: float = _field.height_m(_at(q))
		var after: float = grown.height_m(_at(q))
		assert_true(after >= before - 0.0001, "never lower at %s: %f < %f" % [q, after, before])
		rose += 1 if after > before + 0.01 else 0
	assert_true(rose > 100, "it grew (%d samples)" % rose)
	assert_true(grown.box().encloses(_field.box()), "its box too")


func test_the_yard_is_cut_to_the_ground_and_its_sides_slope_to_it() -> void:
	"""P-2001-5 (a): the yard's cells exactly at the ground; past its first cell its sides rise at YARD_SLOPE."""
	var yard: PackedInt32Array = Mound.yard_cells(Mound.cell_of(_door), _door.z)
	for at: int in range(0, yard.size(), 2):
		var cell: Vector2i = Vector2i(yard[at], yard[at + 1])
		assert_true(_field.is_yard(cell), "a yard cell %s" % cell)
		assert_equal(_field.height_m(_at(Vector2(cell) + Vector2(0.5, 0.5))), 0.0, "at the ground")
	assert_false(_field.is_yard(Vector2i(12, 10)), "never a room cell")
	var side: float = _field.height_m(_at(Vector2(9.5, 8.5)))
	assert_true(is_equal_approx(side, Field.YARD_SLOPE * 0.5), "half a metre beside the yard: %f" % side)
	var plain: Field = _made(_rect(Vector2i(10, 10), Vector2i(19, 13)), [] as Array[Vector3i])
	assert_true(plain.height_m(_at(Vector2(13.0, 9.5))) > Field.ROOM_TOP_M, "with no door the berm runs on")
	assert_false(plain.is_yard(Vector2i(13, 9)), "no yard")


func test_the_turf_comes_down_over_the_eave_behind_the_front() -> void:
	"""BUILD-MOUND-011's look: behind the front the hill falls to the eave's curve; `in_eave` names those points."""
	var front: Vector2 = Field.front_start(_door)
	assert_equal(front, Vector2(12.0, 10.0), "a north door's front starts at its cell's north-west corner")
	var middle: Vector2 = front + Vector2(1.0, 0.1)
	assert_true(_field.in_eave(_at(middle)), "just behind the front")
	assert_false(_field.in_eave(_at(front + Vector2(1.0, 1.5))), "past EAVE_BACK_M")
	assert_false(_field.in_eave(_at(front + Vector2(5.0, 0.1))), "past the yard's width")
	var expected: float = Field.eave_top(0.0) + 0.1 * Field.EAVE_SLOPE
	assert_true(is_equal_approx(_field.height_m(_at(middle)), expected), "on the eave's curve")
	assert_true(Field.eave_top(0.0) > Field.eave_top(2.0) and Field.eave_top(9.0) == Field.FACE_HIGH_M + Field.EAVE_TURF_M,
		"the eave curves down to its ends")


func test_a_windows_place_is_on_the_slope_at_the_walls_top_metre() -> void:
	"""P-2001-6 (a): where the slope outside its edge falls to the middle of the wall's top metre, facing outward; a
	window between two rooms has no place."""
	var spot: Dictionary = _field.window_spot(Vector3i(17, 13, 2))
	assert_false(spot.is_empty(), "found")
	var point: Vector3 = spot["point"]
	assert_true(absf(point.y - Field.WINDOW_HEIGHT_M) < 0.05, "3.5 m up: %f" % point.y)
	assert_true(float(spot["out_m"]) > Field.SHOULDER_M and float(spot["out_m"]) < Field.BERM_M, "out on the slope")
	assert_true(is_equal_approx(point.x, DATUM.x + 17.5) and point.z > DATUM.y + 14.0, "outside the edge's middle")
	var normal: Vector3 = spot["normal"]
	assert_true(normal.z > 0.2 and normal.y > 0.0, "facing south and up: %s" % normal)
	assert_true(_field.window_spot(Vector3i(15, 11, 1)).is_empty(), "between two rooms")
	var heights: float = _field.height_m(_at(Vector2(17.5, 15.0)))
	_field.window_spot(Vector3i(17, 13, 2))
	assert_equal(_field.height_m(_at(Vector2(17.5, 15.0))), heights, "finding it changes no height")


func test_the_nearest_room_cell_and_distances() -> void:
	"""`nearest_cell`, `found_cell`, `room_distance`, `inside_distance`, `is_room` and `box`."""
	assert_equal(_field.nearest_cell(_at(Vector2(15.5, 11.5))), Vector2i(15, 11), "its own cell")
	assert_equal(_field.nearest_cell(_at(Vector2(21.0, 12.5))), Vector2i(19, 12), "east of the rooms")
	assert_equal(_field.found_cell(), Vector2i(19, 12), "kept")
	assert_equal(_field.nearest_cell(_at(Vector2(40.0, 40.0))), Field.NONE, "past the search")
	assert_true(is_equal_approx(_field.room_distance(_at(Vector2(21.0, 12.5))), 1.0), "a metre out")
	assert_equal(_field.room_distance(_at(Vector2(40.0, 40.0))), INF, "past the search")
	assert_true(is_equal_approx(_field.inside_distance(_at(Vector2(12.0, 11.5))), 1.5), "1.5 m inside the north wall")
	assert_equal(_field.inside_distance(_at(Vector2(5.0, 5.0))), 0.0, "off the rooms")
	assert_true(_field.is_room(Vector2i(19, 13)) and not _field.is_room(Vector2i(20, 13)), "rooms")
	assert_equal(_field.box(), Rect2i(10 - Field.REACH, 10 - Field.REACH, 10 + 2 * Field.REACH, 4 + 2 * Field.REACH), "box")
	_field.height_m(_at(Vector2(12.5, 9.5)))
	assert_equal(_field.found_cell(), Field.NONE, "a yard point finds none")


func test_the_static_helpers() -> void:
	"""`berm`, `ring_cell`, `to_square`, `wobble`, `edge_middle`, `front_start` and `normal_at`."""
	assert_equal([Field.berm(0.0), Field.berm(Field.SHOULDER_M), Field.berm(Field.BERM_M), Field.berm(9.0)],
		[1.0, 1.0, 0.0, 0.0], "level, then down to nothing")
	var last: float = 1.0
	for k: int in 30:
		var b: float = Field.berm(k * 0.1)
		assert_true(b <= last, "never rising")
		last = b
	var ring: Dictionary = {}
	for k: int in 16:
		var cell: Vector2i = Field.ring_cell(2, k)
		assert_equal(maxi(absi(cell.x), absi(cell.y)), 2, "on ring 2")
		ring[cell] = true
	assert_equal(ring.size(), 16, "every cell once")
	assert_equal(Field.ring_cell(1, 0), Vector2i(-1, -1), "from the north-west corner")
	assert_equal(Field.to_square(Vector2(0.5, 0.5), Vector2i(0, 0)), 0.0, "inside")
	assert_true(is_equal_approx(Field.to_square(Vector2(4.0, 5.0), Vector2i(0, 0)), 5.0), "3-4-5")
	assert_true(absf(Field.wobble(Vector2(3.7, 1.1))) <= Field.WOBBLE_M, "small")
	assert_equal(Field.edge_middle(Vector3i(3, 4, 1)), Vector2(4.0, 4.5), "an east edge's middle")
	assert_equal(Field.front_start(Vector3i(3, 4, 2)), Vector2(3.0, 5.0), "a south door's front")
	assert_equal(Field.front_start(Vector3i(3, 4, 3)), Vector2(3.0, 4.0), "a west door's front")
	assert_equal(_field.normal_at(_at(Vector2(40.0, 40.0))), Vector3.UP, "flat ground")
