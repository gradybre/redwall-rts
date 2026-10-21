extends "res://test/framework/test_case.gd"
## Decision 2043 P-2043-1/2 (a): M5, today's qualified 1 m module five times in a straight line, through the
## `layout_*` functions of the flight geometry. Every number is 2043 §3's arithmetic; F40 through the same functions
## must equal its `steps` record.

const Flight := preload("res://data/underground/full-level-flight-v1/flight_geometry.gd")
const M5: int = Flight.LAYOUT_M5
const F40: int = Flight.LAYOUT_F40
const MODULE_POSTS: Array[int] = [704, 576, 448, 320, 192, 64, 0]


func _depths() -> Array[int]:
	"""L0's two rows one deep, then module j's five rows at j + 1."""
	var out: Array[int] = [1, 1]
	for module: int in 5:
		for row: int in 5:
			out.append(module + 1)
	return out


func _stop(layout: int, beyond: int) -> Vector3i:
	"""A floor stop through the packet API; a refusal fails the test."""
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0])
	assert_true(Flight.layout_floor_stop_into(layout, beyond, out), "stop %d, %d" % [layout, beyond])
	return Vector3i(out[0], out[1], out[2])


func test_only_the_three_layouts_are_valid() -> void:
	"""M5, its M2 interim (2044 P-2044-15) and F40; anything else refuses every derived number and leaves every
	packet untouched."""
	assert_equal([Flight.layout_valid(M5), Flight.layout_valid(Flight.LAYOUT_M2), Flight.layout_valid(F40)],
		[true, true, true], "valid")
	for bad: int in [-1, 3, 7]:
		assert_false(Flight.layout_valid(bad), "%d" % bad)
		assert_equal([Flight.module_count(bad), Flight.layout_row_count(bad), Flight.layout_floor_depth(bad, 0),
			Flight.layout_tread_count(bad), Flight.tread_module(bad, 0), Flight.tread_k(bad, 0),
			Flight.layout_post_length(bad, 0), Flight.layout_cube_count(bad), Flight.layout_deep_cube_count(bad),
			Flight.layout_part_count(bad)], [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1], "%d" % bad)
		assert_equal([Flight.layout_tread_top_y(bad, 0), Flight.layout_tread_far_z(bad, 0),
			Flight.layout_end_wall_z(bad)], [1, 1, 1], "no coordinates")
		assert_equal(Flight.module_translation(bad, 0), Vector3i(0, 1, 0), "no module")
		assert_false(Flight.layout_is_sill(bad, 6) or Flight.layout_is_t0(bad, 0), "no tread")
		var stop: PackedInt32Array = PackedInt32Array([7, 7, 7])
		var cubes: PackedInt32Array = PackedInt32Array([7])
		var bill: PackedInt64Array = PackedInt64Array([7, 7, 7, 7])
		assert_false(Flight.layout_floor_stop_into(bad, 343, stop) or Flight.layout_cubes_into(bad, cubes)
			or Flight.layout_fixture_bill_into(bad, bill) or Flight.layout_total_bill_into(bad, bill), "refused")
		assert_equal([stop, cubes, bill], [PackedInt32Array([7, 7, 7]), PackedInt32Array([7]),
			PackedInt64Array([7, 7, 7, 7])], "untouched")


func test_m5_is_five_modules_each_today_s_flight_moved() -> void:
	"""Module j sits at (0, -1,024j, -5,120j); there is no sixth."""
	assert_equal([Flight.module_count(M5), Flight.module_count(F40)], [5, 1], "modules")
	for module: int in 5:
		assert_equal(Flight.module_translation(M5, module), Vector3i(0, -1024 * module, -5120 * module), "m%d" % module)
	assert_equal([Flight.module_translation(M5, -1), Flight.module_translation(M5, 5), Flight.module_translation(F40, 1)],
		[Vector3i(0, 1, 0), Vector3i(0, 1, 0), Vector3i(0, 1, 0)], "no such module")
	assert_equal(Flight.module_translation(F40, 0), Vector3i.ZERO, "F40's one")
	assert_equal([Flight.M5_MODULES, Flight.MODULE_ROWS, Flight.MODULE_DROP], [5, 5, 1024], "constants")


func test_m5_rows_and_depths_are_2043_s() -> void:
	"""27 rows: L0's two, then five rows a module at depth module + 1; the end wall at -27,648."""
	assert_equal(Flight.layout_row_count(M5), 27, "rows")
	var depths: Array[int] = []
	for row: int in 27:
		depths.append(Flight.layout_floor_depth(M5, row))
	assert_equal(depths, _depths(), "depths")
	assert_equal([Flight.layout_floor_depth(M5, -1), Flight.layout_floor_depth(M5, 27)], [-1, -1], "outside")
	assert_equal([Flight.layout_end_wall_z(M5), Flight.layout_end_wall_z(F40)], [-27648, -23552], "end walls")
	for row: int in 7:
		assert_equal(Flight.layout_floor_depth(M5, row), Flight.floor_depth(Flight.FIRST_ENTRY_STEPS, row), "m0 = today")


func test_m5_treads_repeat_today_s_module() -> void:
	"""35 treads: T0-T5 and a sill per module, today's posts; one T0 and one sill a module."""
	assert_equal([Flight.layout_tread_count(M5), Flight.layout_tread_count(F40)], [35, 39], "treads")
	var posts: Array[int] = []
	var sills: Array[int] = []
	var t0s: Array[int] = []
	for tread: int in 35:
		posts.append(Flight.layout_post_length(M5, tread))
		if Flight.layout_is_sill(M5, tread): sills.append(tread)
		if Flight.layout_is_t0(M5, tread): t0s.append(tread)
	var expected: Array[int] = []
	for module: int in 5:
		expected.append_array(MODULE_POSTS)
	assert_equal(posts, expected, "posts")
	assert_equal([sills, t0s], [[6, 13, 20, 27, 34], [0, 7, 14, 21, 28]], "sills and T0s")
	assert_equal([Flight.tread_module(M5, 7), Flight.tread_k(M5, 7), Flight.tread_module(M5, 34),
		Flight.tread_k(M5, 34), Flight.tread_module(M5, 35), Flight.tread_k(M5, -1)], [1, 0, 4, 6, -1, -1], "indices")
	assert_equal([Flight.layout_tread_top_y(M5, 7), Flight.layout_tread_far_z(M5, 7)], [-1152, -7680], "m1 T0")
	assert_equal([Flight.layout_tread_top_y(M5, 34), Flight.layout_tread_far_z(M5, 34)], [-4992, -26112], "last sill")
	assert_equal([Flight.layout_tread_top_y(M5, 35), Flight.layout_post_length(M5, 35)], [1, -1], "no tread 35")
	assert_equal([Flight.tread_module(F40, 10), Flight.tread_k(F40, 10), Flight.tread_k(F40, 38)], [0, 10, 38], "F40")
	assert_equal([Flight.layout_is_sill(F40, 38), Flight.layout_is_sill(F40, 6), Flight.layout_is_t0(F40, 7),
		Flight.layout_is_t0(F40, 0), Flight.layout_is_sill(M5, 35), Flight.layout_is_t0(M5, -7)],
		[true, false, false, true, false, false], "F40's one sill and one T0; no tread is neither")
	for tread: int in 39:
		assert_equal(Flight.layout_post_length(F40, tread), Flight.post_length(Flight.F40_STEPS, tread), "F40 %d" % tread)


func test_every_m5_tread_bears_on_its_row_and_every_landing_is_the_last_floor() -> void:
	"""Each deck lies in one row; a post's foot is that row's floor; a sill stands 128 u on it; module j's T0 is
	128 u below the landing, which is module j - 1's floor."""
	for tread: int in 35:
		var far: int = Flight.layout_tread_far_z(M5, tread)
		@warning_ignore("integer_division") var row: int = (-far - 1) / 1024
		assert_true(far + 512 <= -1024 * row, "tread %d inside row %d" % [tread, row])
		var floor_y: int = -1024 * Flight.layout_floor_depth(M5, row)
		var top: int = Flight.layout_tread_top_y(M5, tread)
		if Flight.layout_is_sill(M5, tread):
			assert_equal(top - floor_y, 128, "sill %d on its floor" % tread)
		else:
			assert_equal(top - Flight.DECK_AND_BEARER - Flight.layout_post_length(M5, tread), floor_y, "T%d" % tread)
	for module: int in range(1, 5):
		assert_equal(Flight.layout_tread_top_y(M5, 7 * module) + 128, -1024 * module, "landing %d" % module)
		assert_equal(Flight.layout_floor_depth(M5, 5 * module + 1), module, "the previous run-out")


func test_the_floor_and_landing_stops() -> void:
	"""F, F', U on the level floor; a landing's H' 512 u behind its T0; refusals leave packets untouched."""
	assert_equal(_stop(M5, Flight.FLOOR_ARRIVAL), Vector3i(0, -5120, -26455), "F")
	assert_equal(_stop(M5, Flight.FLOOR_WALK_OFF), Vector3i(0, -5120, -26798), "F'")
	assert_equal(_stop(M5, Flight.FLOOR_ASCENT_START), Vector3i(0, -5120, -26281), "U")
	assert_equal(_stop(F40, Flight.FLOOR_ARRIVAL), Vector3i(0, -5120, -22359), "F40's F, as its record")
	var out: PackedInt32Array = PackedInt32Array([7, 7, 7])
	assert_false(Flight.layout_floor_stop_into(M5, Flight.RUN_OUT, out), "at the end wall")
	assert_false(Flight.layout_floor_stop_into(M5, 343, PackedInt32Array([0])), "packet")
	assert_true(Flight.landing_stop_into(M5, 1, 512, out), "H' of module 1")
	assert_equal(out, PackedInt32Array([0, -1024, -6656]), "H' of module 1")
	assert_true(Flight.landing_stop_into(M5, 4, Flight.RUN_OUT - 1, out), "the landing's uphill end")
	assert_equal(out, PackedInt32Array([0, -4096, -20993]), "module 4's landing end")
	out = PackedInt32Array([7, 7, 7])
	for args: Array in [[0, 512], [5, 512], [1, 0], [1, Flight.RUN_OUT]]:
		assert_false(Flight.landing_stop_into(M5, args[0], args[1], out), "refused %s" % str(args))
	assert_false(Flight.landing_stop_into(F40, 1, 512, out) or Flight.landing_stop_into(M5, 1, 512, PackedInt32Array()),
		"F40 has no landings; packet")
	assert_equal(out, PackedInt32Array([7, 7, 7]), "untouched")


func test_m5_cuts_154_cubes_100_below_the_first_metre() -> void:
	"""2 + 5 x 15 = 77 a column; module 0's cubes are today's flight's; the last box is the deepest run-out cube."""
	assert_equal([Flight.layout_cube_count(M5), Flight.layout_deep_cube_count(M5)], [154, 100], "cubes")
	assert_equal([Flight.layout_cube_count(F40), Flight.layout_deep_cube_count(F40)], [142, 96], "F40 as recorded")
	var boxes: PackedInt32Array = PackedInt32Array([7])
	assert_true(Flight.layout_cubes_into(M5, boxes), "boxes")
	assert_equal(boxes.size(), 154 * 6, "one box a cube")
	var today: PackedInt32Array = PackedInt32Array()
	assert_true(Flight.cubes_into(Flight.FIRST_ENTRY_STEPS, today), "today")
	assert_equal(boxes.slice(0, today.size()), today, "module 0 is today's trench")
	assert_equal(boxes.slice(today.size(), today.size() + 12), PackedInt32Array([-1024, -1024, -8192, 0, 0, -7168,
		-1024, -2048, -8192, 0, -1024, -7168]), "row 7: module 1's first row, two deep")
	assert_equal(boxes.slice(boxes.size() - 6), PackedInt32Array([0, -5120, -27648, 1024, -4096, -26624]), "last")
	var seen: Dictionary = {}
	for at: int in range(0, boxes.size(), 6):
		var key: Vector3i = Vector3i(boxes[at], boxes[at + 1], boxes[at + 2])
		assert_false(seen.has(key), "unique %s" % key)
		seen[key] = true
	var f40: PackedInt32Array = PackedInt32Array()
	var record: PackedInt32Array = PackedInt32Array()
	assert_true(Flight.layout_cubes_into(F40, f40) and Flight.cubes_into(Flight.F40_STEPS, record), "F40")
	assert_equal(f40, record, "F40 through the layout equals its record")


func test_m5_parts_fit_the_catalog() -> void:
	"""7 + 5 x (6 x 7 + 3) = 232 parts, under the catalog's 256; F40's 276 as recorded."""
	assert_equal([Flight.layout_part_count(M5), Flight.layout_part_count(F40)], [232, 276], "parts")


func test_m5_bill_is_2043_s() -> void:
	"""Fixtures wood 39,000, 261,200 milli-WU; total wood 77,500, stone 38,500, 912,620 milli-WU, earth 308,000.
	F40 through the layout keeps its record."""
	var bill: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	assert_true(Flight.layout_fixture_bill_into(M5, bill), "fixtures")
	assert_equal(bill, PackedInt64Array([39000, 0, 261200, 0]), "fixtures")
	assert_true(Flight.layout_total_bill_into(M5, bill), "total")
	assert_equal(bill, PackedInt64Array([77500, 38500, 912620, 308000]), "total")
	var record: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	assert_true(Flight.layout_total_bill_into(F40, bill) and Flight.total_bill_into(Flight.F40_STEPS, record), "F40")
	assert_equal(bill, record, "F40 through the layout equals its record")
	assert_true(Flight.layout_fixture_bill_into(F40, bill) and Flight.fixture_bill_into(Flight.F40_STEPS, record), "fx")
	assert_equal(bill, record, "F40's fixtures")
	var wrong: PackedInt64Array = PackedInt64Array([7, 7, 7])
	assert_false(Flight.layout_fixture_bill_into(M5, wrong) or Flight.layout_total_bill_into(M5, wrong), "packet")
	assert_equal(wrong, PackedInt64Array([7, 7, 7]), "untouched")


func test_m2_is_m5s_first_two_modules() -> void:
	"""Decision 2044 (P-2044-15): M2 has M5's first two modules exactly, ending on module 1's floor 2,048 u down."""
	var m2: int = Flight.LAYOUT_M2
	assert_equal([Flight.module_count(m2), Flight.layout_row_count(m2), Flight.layout_tread_count(m2)], [2, 12, 14],
		"two modules, twelve rows, fourteen treads")
	assert_equal(Flight.layout_end_wall_z(m2), -12288, "the end wall")
	for row: int in Flight.layout_row_count(m2):
		assert_equal(Flight.layout_floor_depth(m2, row), Flight.layout_floor_depth(M5, row), "row %d's depth" % row)
	for tread: int in Flight.layout_tread_count(m2):
		assert_equal([Flight.layout_tread_top_y(m2, tread), Flight.layout_tread_far_z(m2, tread),
			Flight.layout_post_length(m2, tread), Flight.layout_is_sill(m2, tread)],
			[Flight.layout_tread_top_y(M5, tread), Flight.layout_tread_far_z(M5, tread),
			Flight.layout_post_length(M5, tread), Flight.layout_is_sill(M5, tread)], "tread %d" % tread)
	assert_equal(Flight.layout_part_count(m2), 97, "the M2 bundle's 97 parts")
	assert_equal(Flight.module_translation(m2, 2), Vector3i(0, 1, 0), "no third module")
