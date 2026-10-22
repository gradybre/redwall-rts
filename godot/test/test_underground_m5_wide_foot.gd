extends "res://test/framework/test_case.gd"
## Decision 2046 (P-2054-3 (a), Brendan 2026-10-22, "Widen it"): M5's bottom run-out cut one cell wider on each side,
## so a painted level-1 room's front work station can strike a single cube and be reached by a turn. Decision 2054's
## B4 proof (`test_no_front_station_at_m5s_foot_both_strikes_one_cube_and_is_turned_into`, slice D2) re-run on content
## 12's own rows: on the 2-cell foot no front station both strikes one cube and stands on a line where the all-yaw
## ground row 42 turns; on the widened foot (the last two rows four cells wide) the end wall's does. Measured in the
## foot's own frame: x from the slot's centre line, z up the flight from the run-out's end wall, y up from level 1's
## floor. The walls, the end wall and the last sill come from `flight_geometry.gd`.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Flight := preload("res://data/underground/full-level-flight-v1/flight_geometry.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const WIRE: String = "res://data/underground/mole-worker/qualified-stair-carry-v13/mole-worker.ugprof"
const CONTENT: int = 12
const M5: int = Flight.LAYOUT_M5
## Content 12's claw rows (decision 1971): the wall rows 67 (yaw 0, the end wall), 68 and 70 (the side walls), the
## all-yaw ground WALK 42, and the yaw-0 narrow approach and retreat 43/47 a front station is reached on.
const GROUND_ROW: int = 42
const END_WALL_ROW: int = 67
const SIDE_WALL_ROWS: PackedInt32Array = [68, 70]
const STRAIGHT_ROWS: PackedInt32Array = [43, 47]
## The roles a body occupies (as WorldRoutes sweeps them, and a front station's approach).
const BODY_ROLES: PackedInt32Array = [Profiles.BODY_HELD_LOAD, Profiles.TURN_RECOVERY, Profiles.WORK_APPROACH]

var _profiles: Profiles = null


func before_each() -> void:
	"""Content 12's profile wire, loaded on its own."""
	_profiles = Profiles.new()
	var packed: int = 2 * (85 * Profiles.PROFILE_WIRE_BYTES + 637 * 28 + 8 * 32 + 32)
	assert_equal(_profiles.configure(85, 637, 8, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	assert_equal(_profiles.load_file(WIRE, Pins.WIRE_SHA, CONTENT), &"", "content 12")


func after_each() -> void:
	"""Nothing is retained."""
	_profiles = null


func _boxes(row: int, roles: PackedInt32Array) -> Array[PackedInt32Array]:
	"""The row's boxes of the given roles as [low x, low y, low z, high x, high y, high z], relative to its root."""
	var d: Profiles.Descriptor = Profiles.Descriptor.new()
	var box: Profiles.Box = Profiles.Box.new()
	var out: Array[PackedInt32Array] = []
	assert_equal(_profiles.descriptor_into(row, CONTENT, d), &"", "row %d" % row)
	for ordinal: int in d.box_count:
		_profiles.box_into(row, d.profile_revision, CONTENT, ordinal, box)
		if box.role in roles:
			out.append(PackedInt32Array([box.low.x, box.low.y, box.low.z, box.high.x, box.high.y, box.high.z]))
	return out


func _sill() -> PackedInt32Array:
	"""The last sill as [far edge z, top y] from the end wall and the floor (the flight's own geometry)."""
	var last: int = Flight.layout_tread_count(M5) - 1
	var wall: int = Flight.layout_end_wall_z(M5)
	return PackedInt32Array([Flight.layout_tread_far_z(M5, last) - wall,
		Flight.layout_tread_top_y(M5, last) + Flight.LEVEL_DROP])


func _half_width(z: int, wide: bool) -> int:
	"""The cut's half width at `z` from the end wall: the slot's, or the widened foot's over its last rows."""
	if wide and z < Flight.QUANTUM * Flight.layout_foot_rows(M5): return Flight.layout_foot_half_width(M5)
	return Flight.HALF_WIDTH


func _blocked(row: int, at: Vector2i, wide: bool) -> String:
	"""Why the row's body standing at (x, z) meets a side wall, the end wall or the last sill, or ""."""
	var sill: PackedInt32Array = _sill()
	for box: PackedInt32Array in _boxes(row, BODY_ROLES):
		var low: Vector3i = Vector3i(at.x + box[0], box[1], at.y + box[2])
		var high: Vector3i = Vector3i(at.x + box[3], box[4], at.y + box[5])
		if low.z < 0: return "row %d meets the end wall" % row
		for z: int in [low.z, high.z - 1]:
			if low.x < -_half_width(z, wide) or high.x > _half_width(z, wide): return "row %d meets a side wall" % row
		var over_sill: bool = low.x < Flight.HALF_WIDTH and high.x > -Flight.HALF_WIDTH
		if over_sill and high.z > sill[0] and (maxi(low.y, 0) < sill[1] or high.z > sill[0] + Flight.RUN):
			return "row %d meets the sill" % row
	return ""


func _stroke(row: int, axis: int) -> Vector2i:
	"""The wall row's stroke above the stance plane along `axis`, relative to its root: what
	`underground_work_face.gd` requires inside the struck cube alone."""
	var out: Vector2i = Vector2i(1 << 20, -(1 << 20))
	for box: PackedInt32Array in _boxes(row, PackedInt32Array([Profiles.WORK_STROKE])):
		if box[4] <= 0: continue
		out = Vector2i(mini(out.x, box[axis]), maxi(out.y, box[axis + 3]))
	return out


func _patch_z(row: int) -> int:
	"""The wall row's contact patch plane along z, relative to its root (the struck face)."""
	var boxes: Array[PackedInt32Array] = _boxes(row, PackedInt32Array([Profiles.CONTACT_PATCH]))
	assert_equal(boxes.size(), 1, "row %d has one patch" % row)
	assert_equal(boxes[0][2], boxes[0][5], "a face plane across z")
	return boxes[0][2]


func _turn_span(wide: bool, axis: int) -> Vector2i:
	"""Where row 42 turns (its corner) along `axis`, from its own boxes: x on the turn line, z from the end wall."""
	var reach: int = 0
	for box: PackedInt32Array in _boxes(GROUND_ROW, BODY_ROLES):
		reach = maxi(reach, maxi(-box[axis], box[axis + 3]))
	if axis == 0:
		var half: int = Flight.layout_foot_half_width(M5) if wide else Flight.HALF_WIDTH
		return Vector2i(-half + reach, half - reach)
	return Vector2i(reach, _sill()[0] - reach)


func _fits(row: int, axis: int, cell: int) -> Vector2i:
	"""The roots across the heading from which the row's stroke lies in the cell [cell, cell + 1,024) alone."""
	var stroke: Vector2i = _stroke(row, axis)
	return Vector2i(cell - stroke.x, cell + Flight.QUANTUM - stroke.y)


func _cells(wide: bool) -> PackedInt32Array:
	"""The run-out's cells across the flight, by their low x."""
	var half: int = Flight.layout_foot_half_width(M5) if wide else Flight.HALF_WIDTH
	var out: PackedInt32Array = PackedInt32Array()
	for cell: int in range(-half, half, Flight.QUANTUM): out.append(cell)
	return out


func test_the_widened_foot_is_four_cells_over_the_last_two_rows() -> void:
	"""P-2054-3 (a): the run-out's two rows (the last sill's far half and the end row) one cell wider on each side,
	4,096 u across, at every depth (open to the sky, as the slot is); the rest of the slot keeps its two cells."""
	assert_equal(Flight.layout_foot_half_width(M5), 2 * Flight.HALF_WIDTH, "two cells either side of the centre line")
	assert_equal(Flight.layout_foot_rows(M5), 2, "the last two rows")
	assert_true(Flight.QUANTUM * Flight.layout_foot_rows(M5) >= Flight.RUN_OUT, "they hold the whole run-out")
	assert_equal(_sill(), PackedInt32Array([Flight.RUN_OUT, Flight.RISE]), "the sill's far edge RUN_OUT from the wall")
	for layout: int in [Flight.LAYOUT_M2, Flight.LAYOUT_F40]:
		assert_equal([Flight.layout_foot_half_width(layout), Flight.layout_foot_rows(layout)], [Flight.HALF_WIDTH, 0],
			"layout %d keeps the slot's width" % layout)


func test_on_the_two_cell_foot_no_front_station_strikes_one_cube_and_is_turned_into() -> void:
	"""Decision 2054 B4, kept as the record: in the 2-cell run-out the end wall's stations (67, across x) and the side
	walls' (68 and 70, across z) never stand on a line where row 42 turns."""
	var cases: Array = [[END_WALL_ROW, 0, _cells(false), _turn_span(false, 0)],
		[SIDE_WALL_ROWS[0], 2, PackedInt32Array([0, Flight.QUANTUM]), _turn_span(false, 2)],
		[SIDE_WALL_ROWS[1], 2, PackedInt32Array([0, Flight.QUANTUM]), _turn_span(false, 2)]]
	assert_equal(_turn_span(false, 0), Vector2i(-312, 312), "2054's turning line")
	assert_equal(_turn_span(false, 2), Vector2i(712, 824), "2054's turning depth")
	for case: Array in cases:
		var stroke: Vector2i = _stroke(case[0], case[1])
		assert_true(stroke.y - stroke.x <= Flight.QUANTUM, "row %d's stroke fits one cube" % case[0])
		for cell: int in case[2]:
			var fits: Vector2i = _fits(case[0], case[1], cell)
			assert_true(fits.x <= fits.y, "row %d: stations in cell %d strike it alone from %s" % [case[0], cell, fits])
			assert_true(fits.y < case[3].x or fits.x > case[3].y,
				"row %d, cell %d: no station on a turnable line (%s against %s)" % [case[0], cell, fits, case[3]])


func test_on_the_widened_foot_the_end_walls_front_strikes_one_cube_and_is_turned_into() -> void:
	"""B4 closed: four cells across, row 42 turns on any line within 1,336 u of the centre line, so the end wall's
	inner cells each have stations that strike them alone (478-609 u in) on a turnable line. One is built out: the
	corner where 42 turns, the straight walk on 43/47 down onto the station and the station's own wall row clear the
	widened walls, the end wall and the sill; one unit outside either range, they do not."""
	var turn: Vector2i = _turn_span(true, 0)
	assert_equal(turn, Vector2i(-1336, 1336), "the widened turning line")
	var met: int = 0
	for cell: int in _cells(true):
		var fits: Vector2i = _fits(END_WALL_ROW, 0, cell)
		if fits.y >= turn.x and fits.x <= turn.y: met += 1
	assert_equal(met, 2, "both inner cells (the outer cells' stations lie past the turning line)")
	var fits: Vector2i = _fits(END_WALL_ROW, 0, -Flight.QUANTUM)
	assert_equal(fits, Vector2i(-546, -415), "the west inner cell's stations")
	var depth: Vector2i = _turn_span(true, 2)
	assert_equal(depth, Vector2i(712, 824), "row 42 turns 712-824 u from the end wall, short of the sill")
	var station: Vector2i = Vector2i(-480, -_patch_z(END_WALL_ROW)) # The wall row's patch on the end wall's face.
	var corner: Vector2i = Vector2i(station.x, depth.x)
	assert_equal(_blocked(GROUND_ROW, corner, true), "", "row 42 turns at the corner")
	assert_true(_blocked(GROUND_ROW, corner, false) != "", "it does not on the 2-cell foot")
	for row: int in STRAIGHT_ROWS:
		assert_equal(_blocked(row, corner, true), "", "row %d at the corner" % row)
		assert_equal(_blocked(row, station, true), "", "row %d at the station" % row)
	assert_equal(_blocked(END_WALL_ROW, station, true), "", "the wall row at its station")
	assert_true(_blocked(END_WALL_ROW, station - Vector2i(0, 56), true) != "", "56 u nearer: its body meets the wall")
	assert_true(_blocked(GROUND_ROW, corner + Vector2i(0, -1), true) != "", "one unit nearer the wall: no turn")
	assert_true(_blocked(GROUND_ROW, Vector2i(station.x, depth.y + 1), true) != "", "one unit nearer the sill: none")
	assert_true(_blocked(GROUND_ROW, Vector2i(turn.x - 1, depth.x), true) != "", "one unit west of the line: none")


func test_a_run_out_one_row_longer_admits_a_side_wall_front_in_the_two_cell_slot() -> void:
	"""Decision 2046 P-2046-1 (b), for the ruling: on today's 2-cell foot, row 42's turning depth is bounded by the end
	wall and the last sill (712-824 u), so no side-wall station line meets it. With the run-out one row longer
	(RUN_OUT + 1,024 = 2,560 u from the sill's far edge to the end wall) it turns 712-1,848 u from the wall, which holds
	the side walls' stations in the middle row's cells (1,439-1,570 u west, 1,502-1,633 u east). One is built out: the corner on the slot's
	centre line, the walk across on 68's own heading rows, the wall row at its station, all clear of the 2-cell walls,
	the end wall and the sill moved one row further from the wall."""
	var longer: int = Flight.RUN_OUT + Flight.QUANTUM
	var reach: int = _turn_span(false, 2).x
	var depth: Vector2i = Vector2i(reach, longer - reach)
	assert_equal(depth, Vector2i(712, 1848), "row 42 turns 712-1,848 u from the end wall")
	var expected: Array[Vector2i] = [Vector2i(1439, 1570), Vector2i(1502, 1633)]
	for at: int in SIDE_WALL_ROWS.size():
		var row: int = SIDE_WALL_ROWS[at]
		var fits: Vector2i = _fits(row, 2, Flight.QUANTUM)
		assert_equal(fits, expected[at], "row %d's stations in the middle row's cell" % row)
		assert_true(fits.x >= depth.x and fits.y <= depth.y, "row %d: every one of them on a turnable line" % row)
	var station: Vector2i = Vector2i(-Flight.HALF_WIDTH - _patch_x(SIDE_WALL_ROWS[0]), 1500)
	var corner: Vector2i = Vector2i(0, station.y)
	var sill: Vector2i = Vector2i(longer, Flight.RISE)
	assert_equal(_blocked_at(GROUND_ROW, corner, sill), "", "row 42 turns at the corner on the centre line")
	assert_equal(_blocked_at(SIDE_WALL_ROWS[0], station, sill), "", "the west wall row at its station")
	assert_true(_blocked_at(GROUND_ROW, corner, Vector2i(_sill()[0], _sill()[1])) != "", "with today's run-out the corner meets the sill")


func _patch_x(row: int) -> int:
	"""A side wall row's contact patch plane along x, relative to its root (the struck face)."""
	var boxes: Array[PackedInt32Array] = _boxes(row, PackedInt32Array([Profiles.CONTACT_PATCH]))
	assert_equal(boxes[0][0], boxes[0][3], "a face plane across x")
	return boxes[0][0]


func _blocked_at(row: int, at: Vector2i, sill: Vector2i) -> String:
	"""`_blocked` on the 2-cell slot against a sill whose far edge is `sill.x` from the end wall, `sill.y` high."""
	for box: PackedInt32Array in _boxes(row, BODY_ROLES):
		var low: Vector3i = Vector3i(at.x + box[0], box[1], at.y + box[2])
		var high: Vector3i = Vector3i(at.x + box[3], box[4], at.y + box[5])
		if low.z < 0: return "row %d meets the end wall" % row
		if low.x < -Flight.HALF_WIDTH or high.x > Flight.HALF_WIDTH: return "row %d meets a side wall" % row
		if high.z > sill.x and (maxi(low.y, 0) < sill.y or high.z > sill.x + Flight.RUN):
			return "row %d meets the sill" % row
	return ""


func test_the_side_walls_still_admit_no_front_on_the_widened_foot() -> void:
	"""Recorded, not asked: the side walls' stations (68 and 70, across z) stand 415-546 u or 1,439-1,570 u from the
	end wall; row 42 still turns only 712-824 u from it (the end wall and the sill bound it, whatever the width), so
	a level-1 room at the foot opens from the end wall."""
	var depth: Vector2i = _turn_span(true, 2)
	for row: int in SIDE_WALL_ROWS:
		for cell: int in [0, Flight.QUANTUM]:
			var fits: Vector2i = _fits(row, 2, cell)
			assert_true(fits.y < depth.x or fits.x > depth.y, "row %d, cell %d: %s against %s" % [row, cell, fits, depth])
