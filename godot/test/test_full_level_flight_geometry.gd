extends "res://test/framework/test_case.gd"
## Decision 2041 §2: F40's derived geometry and bill, number by number, and the same rule reproducing today's
## qualified 1 m flight (ADR 1209, its measured ledger in decision 1229) as the cross-check (F5).

const Flight := preload("res://data/underground/full-level-flight-v1/flight_geometry.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/tread_geometry.gd")
const F40: int = 40
const ONE_METRE: int = 8
const LEVEL_PACK: String = "res://data/underground/initial_level_pack.json"
const F40_DEPTHS: Array[int] = [1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5]
const CYCLE: Array[int] = [960, 832, 704, 576, 448, 320, 192, 64]


func _f40_posts() -> Array[int]:
	"""2041 §2.4: T0-T5 as today, then the eight-tread cycle four times, then the sill."""
	var posts: Array[int] = [704, 576, 448, 320, 192, 64]
	for plateau: int in 4:
		posts.append_array(CYCLE)
	posts.append(0)
	return posts


func test_only_the_two_ruled_flights_are_valid() -> void:
	"""F40 and today's 1 m flight; every other count, the unruled 16-32 included, refuses every derived number."""
	assert_equal([Flight.valid(8), Flight.valid(40)], [true, true], "valid")
	for bad: int in [0, -8, 7, 12, 16, 24, 32, 39, 41, 48]:
		assert_false(Flight.valid(bad), "%d refused" % bad)
		assert_equal([Flight.drop_u(bad), Flight.bottom_depth(bad), Flight.tread_count(bad), Flight.sill(bad),
			Flight.row_count(bad), Flight.cube_count(bad), Flight.deep_cube_count(bad), Flight.part_count(bad),
			Flight.top_landing_cubes(bad), Flight.bottom_landing_cubes(bad), Flight.floor_depth(bad, 0),
			Flight.post_length(bad, 0), Flight.tread_cubes(bad, 0)], [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1],
			"%d" % bad)
		assert_equal([Flight.end_wall_z(bad), Flight.floor_y(bad, 0)], [1, 1], "no end wall, no floor")
		assert_false(Flight.is_tread(bad, 0) or Flight.is_sill(bad, 0) or Flight.is_sill(bad, -1), "no tread")
		var stop: PackedInt32Array = PackedInt32Array([7, 7, 7])
		assert_false(Flight.floor_stop_into(bad, Flight.FLOOR_WALK_OFF, stop), "no floor stop")
		assert_equal(stop, PackedInt32Array([7, 7, 7]), "untouched")


func test_f40_is_forty_steps_thirty_nine_treads_and_one_level() -> void:
	"""5,120 u = 40 x 128; T0-T37 and the sill T38; the floor is the level pack's spacing."""
	assert_equal([Flight.drop_u(F40), Flight.bottom_depth(F40), Flight.tread_count(F40), Flight.sill(F40)],
		[5120, 5, 39, 38], "F40")
	assert_equal(Flight.drop_u(Flight.F40_STEPS), Flight.LEVEL_DROP, "one level")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PACK))
	assert_equal(int(pack["level_spacing_u"]), Flight.LEVEL_DROP, "the level pack's own spacing")
	assert_equal([Flight.RISE, Flight.RUN, Flight.QUANTUM], [128, 512, 1024], "pitch")
	assert_equal(Flight.FIRST_ENTRY_STEPS, ONE_METRE, "today's flight")
	assert_equal([Flight.is_tread(F40, -1), Flight.is_tread(F40, 0), Flight.is_tread(F40, 38), Flight.is_tread(F40, 39)],
		[false, true, true, false], "tread range")
	assert_equal([Flight.is_sill(F40, 37), Flight.is_sill(F40, 38)], [false, true], "the sill")


func test_f40_rows_and_depths_are_the_section_2_4_table() -> void:
	"""23 rows; L0 one deep, plateaus of four rows at 1-5, the sill row and run-out at the floor; outside refuses."""
	assert_equal(Flight.row_count(F40), 23, "rows")
	var depths: Array = []
	for row: int in 23:
		depths.append(Flight.floor_depth(F40, row))
	assert_equal(depths, F40_DEPTHS, "depths")
	assert_equal([Flight.floor_depth(F40, -1), Flight.floor_depth(F40, 23)], [-1, -1], "outside")
	assert_equal([Flight.floor_y(F40, 0), Flight.floor_y(F40, 5), Flight.floor_y(F40, 22), Flight.floor_y(F40, 23)],
		[-1024, -2048, -5120, 1], "floors")
	assert_equal(Flight.end_wall_z(F40), -23552, "end wall")
	assert_equal(Flight.far_z(Flight.sill(F40)), -22016, "the sill's far edge: -2,560 - 512 x 38")


func test_f40_posts_add_only_832_and_960() -> void:
	"""Every post 64-960 in 128 u steps; the two new lengths fall on the first two treads of each new plateau."""
	var posts: Array[int] = []
	for k: int in 39:
		posts.append(Flight.post_length(F40, k))
	assert_equal(posts, _f40_posts(), "posts")
	assert_equal([Flight.post_length(F40, -1), Flight.post_length(F40, 39)], [-1, -1], "no tread")
	var long: Array[int] = []
	for k: int in 39:
		if Flight.post_length(F40, k) > 704: long.append(k)
	assert_equal(long, [6, 7, 14, 15, 22, 23, 30, 31], "832/960 treads")


func test_no_cube_floor_keeps_posts_within_t0s_range_in_row_five() -> void:
	"""2041 §2.1: row 2 + m holds T_2m and T_2m+1; both posts in [64, 704] need a floor in [512 + 256m, 1024 + 256m],
	which for m = 3 holds no multiple of 1,024. The loop documents the argument on literals; the module is held to it
	by the last two assertions."""
	for m: int in 4:
		var low: int = 512 + 256 * m
		var high: int = 1024 + 256 * m
		var found: bool = false
		for floor_u: int in range(1024, 6144, 1024):
			found = found or (floor_u >= low and floor_u <= high)
		assert_equal(found, m < 3, "m = %d" % m)
	assert_equal(Flight.floor_depth(F40, 2 + 3) * 1024, 2048, "so row 5 steps to 2,048 and T6 gets 960")
	for m: int in 3:
		assert_equal(Flight.floor_depth(F40, 2 + m), 1, "rows 2-4 stay inside T0's range")


func test_each_tread_lies_wholly_in_its_row_and_bears_on_its_floor() -> void:
	"""T_k's deck [far, far + 512] inside row_of(k); top minus deck and bearer minus post is the row's floor."""
	for k: int in 39:
		var row: int = Flight.row_of(k)
		assert_true(Flight.far_z(k) >= -1024 * (row + 1) and Flight.far_z(k) + 512 <= -1024 * row, "T%d in row" % k)
		if not Flight.is_sill(F40, k):
			assert_equal(Flight.top_y(k) - Flight.DECK_AND_BEARER - Flight.post_length(F40, k), Flight.floor_y(F40, row),
				"T%d bears on the floor" % k)
	assert_equal(Flight.top_y(Flight.sill(F40)) - Flight.floor_y(F40, 21), 128, "the sill stands 128 u on the floor")
	assert_equal([Flight.row_of(-1), Flight.row_of(0), Flight.row_of(1), Flight.row_of(38)], [-1, 2, 2, 21], "rows")
	for k: int in 39:
		assert_equal(Flight.translation(k), Flight.stop(k, 0) - Flight.stop(0, 0), "T%d is T0 moved" % k)
	assert_equal(Flight.translation(38), Vector3i(0, -4864, -19456), "T38")


func test_the_frame_matches_the_qualified_tread_geometry() -> void:
	"""T0-T6 and L0 sit exactly where tread_geometry.gd puts them; so do their stops."""
	for k: int in range(-1, 7):
		assert_equal([Flight.top_y(k), Flight.far_z(k)], [Tread.top_y(k), Tread.far_z(k)], "T%d" % k)
		assert_equal(Flight.stop(k, Tread.STATION), Tread.stop(k, Tread.STATION), "S on T%d" % k)
	assert_equal(Flight.sill(ONE_METRE), Tread.SILL, "today's sill")
	assert_equal(Flight.tread_count(ONE_METRE), Tread.TREADS + 1, "T0 and T1-T6")


func _floor_stop(steps: int, beyond: int) -> Vector3i:
	"""One floor stop through the packet API; a refusal fails the test."""
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0])
	assert_true(Flight.floor_stop_into(steps, beyond, out), "stop %d, %d" % [steps, beyond])
	return Vector3i(out[0], out[1], out[2])


func test_the_floor_stops_are_the_one_metre_stops_moved_down_and_along() -> void:
	"""F, F' and the floor's U at 343, 686 and 169 u past the sill: today's at y -1,024, F40's moved (0, -4,096,
	-16,384); a point at or past the end wall, or a bad packet, refuses."""
	assert_equal(_floor_stop(ONE_METRE, Flight.FLOOR_ARRIVAL), Vector3i(0, -1024, -5975), "F today")
	assert_equal(_floor_stop(ONE_METRE, Flight.FLOOR_WALK_OFF), Vector3i(0, -1024, -6318), "F' today")
	assert_equal(_floor_stop(ONE_METRE, Flight.FLOOR_ASCENT_START), Vector3i(0, -1024, -5801), "U today")
	for beyond: int in [Flight.FLOOR_ASCENT_START, Flight.FLOOR_ARRIVAL, Flight.FLOOR_WALK_OFF]:
		assert_equal(_floor_stop(F40, beyond) - _floor_stop(ONE_METRE, beyond), Vector3i(0, -4096, -16384),
			"moved %d" % beyond)
	assert_equal(_floor_stop(F40, Flight.RUN_OUT - 1).z, Flight.end_wall_z(F40) + 1, "the last point before the wall")
	var out: PackedInt32Array = PackedInt32Array([7, 7, 7])
	for beyond: int in [0, -1, Flight.RUN_OUT]:
		assert_false(Flight.floor_stop_into(F40, beyond, out), "beyond %d refused" % beyond)
	assert_false(Flight.floor_stop_into(F40, 343, PackedInt32Array([0, 0])), "packet size")
	assert_equal(out, PackedInt32Array([7, 7, 7]), "untouched")
	assert_equal(Flight.stop(-1, 0), Vector3i(0, 0, -2048), "L0's far edge")


func test_f40_cuts_142_cubes_96_below_the_first_metre() -> void:
	"""71 a column, two columns; 46 in the top metre; the boxes are exact, unique, and inside the slot."""
	assert_equal([Flight.cube_count(F40), Flight.deep_cube_count(F40)], [142, 96], "cubes")
	var boxes: PackedInt32Array = PackedInt32Array([7])
	assert_true(Flight.cubes_into(F40, boxes), "boxes")
	assert_equal(boxes.size(), 142 * 6, "one box a cube")
	assert_equal(boxes.slice(0, 6), PackedInt32Array([-1024, -1024, -1024, 0, 0, 0]), "first: row 0, -x, top")
	assert_equal(boxes.slice(boxes.size() - 6), PackedInt32Array([0, -5120, -23552, 1024, -4096, -22528]), "last")
	assert_equal(boxes.slice(10 * 6, 14 * 6), PackedInt32Array([-1024, -1024, -6144, 0, 0, -5120,
		-1024, -2048, -6144, 0, -1024, -5120, 0, -1024, -6144, 1024, 0, -5120, 0, -2048, -6144, 1024, -1024, -5120]),
		"row 5's four cubes in storage order: -x column top-down, then +x")
	var seen: Dictionary = {}
	for at: int in range(0, boxes.size(), 6):
		var key: Vector3i = Vector3i(boxes[at], boxes[at + 1], boxes[at + 2])
		assert_false(seen.has(key), "unique %s" % key)
		seen[key] = true
		assert_true(boxes[at + 3] - boxes[at] == 1024 and boxes[at + 4] - boxes[at + 1] == 1024
			and boxes[at + 5] - boxes[at + 2] == 1024, "a cube")
		@warning_ignore("integer_division") var row: int = -boxes[at + 5] / 1024
		assert_true(boxes[at + 1] >= Flight.floor_y(F40, row) and boxes[at] >= -1024 and boxes[at + 3] <= 1024, "inside")
	var refused: PackedInt32Array = PackedInt32Array([7])
	assert_false(Flight.cubes_into(12, refused), "invalid steps")
	assert_equal(refused, PackedInt32Array([7]), "untouched")


func test_the_pieces_share_the_cut_4_123_15() -> void:
	"""Top landing four cubes, the treads 123 (a tread in plateau d takes d), the run-out 15."""
	var treads: int = 0
	for k: int in 39:
		treads += Flight.tread_cubes(F40, k)
	assert_equal([Flight.top_landing_cubes(F40), treads, Flight.bottom_landing_cubes(F40)], [4, 123, 15], "pieces")
	assert_equal([Flight.tread_cubes(F40, 0), Flight.tread_cubes(F40, 6), Flight.tread_cubes(F40, 37),
		Flight.tread_cubes(F40, 38), Flight.tread_cubes(F40, 39)], [1, 2, 5, 5, -1], "per tread")


func test_f40_bill_is_p_df_4() -> void:
	"""Fixtures wood 43,000, 258,320 milli-WU; excavation 142 cubes; total wood 78,500, stone 35,500, 858,980
	milli-WU, earth out 284,000."""
	var bill: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	assert_true(Flight.fixture_bill_into(F40, bill), "fixtures")
	assert_equal(bill, PackedInt64Array([43000, 0, 258320, 0]), "fixtures")
	assert_true(Flight.excavation_bill_into(F40, bill), "excavation")
	assert_equal(bill, PackedInt64Array([35500, 35500, 600660, 284000]), "excavation")
	assert_true(Flight.total_bill_into(F40, bill), "total")
	assert_equal(bill, PackedInt64Array([78500, 35500, 858980, 284000]), "total")
	var wrong: PackedInt64Array = PackedInt64Array([0, 0, 0])
	assert_false(Flight.excavation_bill_into(F40, wrong) or Flight.total_bill_into(F40, wrong)
		or Flight.fixture_bill_into(F40, wrong), "packet size")
	assert_false(Flight.fixture_bill_into(12, bill), "invalid steps")
	assert_false(Flight.total_bill_into(12, bill), "invalid steps")
	assert_equal(bill, PackedInt64Array([78500, 35500, 858980, 284000]), "refusal leaves the packet")


func test_the_rule_reproduces_todays_flight_and_its_ledger() -> void:
	"""F5: 7 rows one deep, 14 cubes, posts 704-64 and the sill, 59,220 + 77,840 milli-WU (decision 1229 line 469)."""
	assert_equal(Flight.row_count(ONE_METRE), 7, "rows")
	var posts: Array[int] = []
	for k: int in 7:
		posts.append(Flight.post_length(ONE_METRE, k))
	assert_equal(posts, [704, 576, 448, 320, 192, 64, 0], "posts")
	for row: int in 7:
		assert_equal(Flight.floor_depth(ONE_METRE, row), 1, "row %d" % row)
	assert_equal([Flight.cube_count(ONE_METRE), Flight.deep_cube_count(ONE_METRE), Flight.end_wall_z(ONE_METRE)],
		[14, 0, -7168], "the trench")
	var bill: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	assert_true(Flight.excavation_bill_into(ONE_METRE, bill), "excavation")
	var fixtures: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	assert_true(Flight.fixture_bill_into(ONE_METRE, fixtures), "fixtures")
	assert_equal([bill[Flight.BILL_WORK], fixtures[Flight.BILL_WORK], fixtures[Flight.BILL_WOOD]],
		[59220, 77840, 11000], "the measured ledger")
	assert_equal([Flight.top_landing_cubes(ONE_METRE), Flight.bottom_landing_cubes(ONE_METRE)], [4, 3], "pieces")


func test_parts_and_rotation() -> void:
	"""276 parts (over the catalog's 256, 2041 F4), 52 today; the rotation mask admits quarter-turn 0 only."""
	assert_equal([Flight.part_count(F40), Flight.part_count(ONE_METRE)], [276, 52], "parts")
	var admitted: Array[int] = []
	for rotation: int in 4:
		if Flight.ALLOWED_ROTATION_MASK & (1 << rotation) != 0: admitted.append(rotation)
	assert_equal(admitted, [0], "P-DF-6 (a)")
	assert_equal([Flight.post_length(F40, Flight.sill(F40)), Flight.post_length(ONE_METRE, Flight.sill(ONE_METRE))],
		[0, 0], "a sill, no posts, at each flight's foot")
