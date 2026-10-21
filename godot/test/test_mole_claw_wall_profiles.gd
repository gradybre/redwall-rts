extends "res://test/framework/test_case.gd"
## Decision 1971: the content-11 publication (`qualified-claw-wall-v12`) loads through the actual Profiles loader and
## validator; its wall rows strike a side face, which sets the painted room height. Data only: not the active catalog.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Planner := preload("res://scripts/core/underground_room_station_planner.gd")
const Wall := preload("res://data/underground/mole-worker/qualified-claw-wall-v12/catalog_source.gd")
const Stairs := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const WALL_WIRE: String = "res://data/underground/mole-worker/qualified-claw-wall-v12/mole-worker.ugprof"
const STAIRS_WIRE: String = "res://data/underground/mole-worker/qualified-claw-stairs-v11/mole-worker.ugprof"
const WALL_COUNTS: Vector3i = Vector3i(71, 595, 6)
const STAIRS_COUNTS: Vector3i = Vector3i(67, 547, 6)
var _wall: Profiles = null
var _stairs: Profiles = null


func before_each() -> void:
	"""Both publications through the actual loader."""
	_wall = _loaded(WALL_WIRE, Wall.WIRE_SHA, 11, WALL_COUNTS)
	_stairs = _loaded(STAIRS_WIRE, Stairs.WIRE_SHA, 10, STAIRS_COUNTS)


func after_each() -> void:
	"""Drop both stores."""
	_wall = null
	_stairs = null


func _loaded(path: String, digest: String, revision: int, counts: Vector3i) -> Profiles:
	"""One configured store with the publication loaded and validated."""
	var store: Profiles = Profiles.new()
	var packed: int = 2 * (counts.x * Profiles.PROFILE_WIRE_BYTES + counts.y * 28 + counts.z * 32 + 32)
	assert_equal(store.configure(counts.x, counts.y, counts.z, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	assert_equal(store.load_file(path, digest, revision), &"", "actual loader and validator")
	return store


func _field(store: Profiles, field: int, row: int) -> int:
	"""One stored descriptor word."""
	return store._live.fields[field * store._profile_capacity + row]


func _boxes(store: Profiles, row: int) -> Array:
	"""Every box word of one row."""
	var result: Array = []
	var first: int = _field(store, Profiles.F_FIRST_BOX, row)
	for box: int in range(first, first + _field(store, Profiles.F_BOX_COUNT, row)):
		for word: int in 7:
			result.append(store._live.boxes[word * store._box_capacity + box])
	return result


func _box(store: Profiles, row: int, role: int) -> PackedInt32Array:
	"""The single box of one role, as six words."""
	var first: int = _field(store, Profiles.F_FIRST_BOX, row)
	for box: int in range(first, first + _field(store, Profiles.F_BOX_COUNT, row)):
		if store._live.boxes[6 * store._box_capacity + box] == role:
			var out: PackedInt32Array = PackedInt32Array()
			for word: int in 6: out.append(store._live.boxes[word * store._box_capacity + box])
			return out
	return PackedInt32Array()


func test_content_ten_rows_are_unchanged() -> void:
	"""Rows 0-66 keep every word but the first-box index, and every box."""
	for row: int in STAIRS_COUNTS.x:
		for field: int in Profiles.I32_FIELDS:
			if field != Profiles.F_FIRST_BOX:
				assert_equal(_field(_wall, field, row), _field(_stairs, field, row), "row %d field %d" % [row, field])
		assert_equal(_boxes(_wall, row), _boxes(_stairs, row), "row %d boxes" % row)


func test_wall_rows_are_m1_at_a_wall() -> void:
	"""Rows 67-70 are source-4 BUILD anchor-and-patch WORK rows at the four yaws, M1's words, contact on the wall."""
	assert_equal(Wall.CLAW_WALL_ROWS, PackedInt32Array([67, 68, 69, 70]), "published row IDs")
	for heading: int in 4:
		var row: int = Wall.CLAW_WALL_ROWS[heading]
		var dig: int = Wall.CLAW_DIG_ROWS[heading]
		for field: int in [Profiles.F_SOURCE, Profiles.F_MODE, Profiles.F_TOOL, Profiles.F_YAW_KIND, Profiles.F_YAW,
				Profiles.F_WORK_KIND, Profiles.F_CONTACT_KIND]:
			assert_equal(_field(_wall, field, row), _field(_wall, field, dig), "row %d field %d" % [row, field])
		var point: PackedInt32Array = _box(_wall, row, Profiles.CONTACT_POINT)
		assert_equal(point[1], 177, "the right claw tip meets the wall 177 u up")
		assert_equal(maxi(absi(point[0]), absi(point[2])), 521, "on the wall plane, 521 u ahead")
	assert_equal(_box(_wall, 67, Profiles.CONTACT_PATCH), PackedInt32Array([-225, 71, -521, 211, 177, -521]), "yaw 0 patch")


func test_only_the_wall_rows_strike_a_side_face() -> void:
	"""The side-face predicate: the top-face dig and the seating tap are flat in y, the wall row in z (yaw 0)."""
	assert_false(Approach._side_patch(_wall, 56), "M1's top-face dig")
	assert_false(Approach._side_patch(_wall, 57), "the paw seating tap")
	assert_true(Approach._side_patch(_wall, 67), "the wall row")
	var query: Planner.Query = Planner.Query.new()
	query.profiles = _wall
	query.axis = 2
	assert_false(Planner._patch_on_face(query, 56), "planner: the top-face dig strikes no z face")
	assert_false(Planner._patch_on_face(query, 57), "planner: the tap strikes no z face")
	assert_true(Planner._patch_on_face(query, 67), "planner: the wall row strikes the z face")
	query.axis = 0
	assert_false(Planner._patch_on_face(query, 67), "planner: the yaw-0 wall row strikes no x face")


func test_content_eleven_digs_the_painted_height() -> void:
	"""P-1971-3 (b): the claw crew strikes the floor band of a side face, so the stroke sets no height limit."""
	assert_equal(Approach.reachable_height_u(_wall, Wall.CLAW_DIG_ROWS[0]), Approach.UNLIMITED_HEIGHT_U, "claw crew")
	assert_equal(Approach.reachable_height_u(_wall, -1), Approach.UNLIMITED_HEIGHT_U, "any crew")
	assert_equal(mini(4096, Approach.reachable_height_u(_wall, Wall.CLAW_DIG_ROWS[0])), 4096, "the clear height: 4 quanta")


func test_content_without_a_side_face_row_reaches_nothing() -> void:
	"""Decision 1972 deleted decision 1971's LEGACY band: content 10's claw crew has no side-face row, so it reaches
	nothing at any content revision."""
	assert_equal(Approach.reachable_height_u(_stairs, Stairs.CLAW_DIG_ROWS[0]), 0, "content 10: no side-face row")
	_stairs._live.header[0] = 12
	assert_equal(Approach.reachable_height_u(_stairs, Stairs.CLAW_DIG_ROWS[0]), 0, "relabelled 12: still nothing")
	_stairs._live.header[0] = 10


func _set_anchor_height(row: int, height: int) -> void:
	"""Negative-only: move one loaded row's CONTACT_POINT to another height above the stance."""
	var first: int = _field(_wall, Profiles.F_FIRST_BOX, row)
	for box: int in range(first, first + _field(_wall, Profiles.F_BOX_COUNT, row)):
		if _wall._live.boxes[6 * _wall._box_capacity + box] == Profiles.CONTACT_POINT:
			_wall._live.boxes[_wall._box_capacity + box] = height
			_wall._live.boxes[4 * _wall._box_capacity + box] = height


func test_only_an_anchor_inside_the_floor_band_lifts_the_limit() -> void:
	"""An anchor on the floor plane or the band's top plane strikes no side of the floor-band cube."""
	for row: int in Wall.CLAW_WALL_ROWS:
		_set_anchor_height(row, 0)
	assert_equal(Approach.reachable_height_u(_wall, Wall.CLAW_DIG_ROWS[0]), 0, "an anchor on the floor plane")
	for row: int in Wall.CLAW_WALL_ROWS:
		_set_anchor_height(row, 1024)
	assert_equal(Approach.reachable_height_u(_wall, Wall.CLAW_DIG_ROWS[0]), 0, "an anchor on the band's top plane")
	for row: int in Wall.CLAW_WALL_ROWS:
		_set_anchor_height(row, 177)
	assert_equal(Approach.reachable_height_u(_wall, Wall.CLAW_DIG_ROWS[0]), Approach.UNLIMITED_HEIGHT_U, "restored")

