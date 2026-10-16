extends "res://test/framework/test_case.gd"
## Decision 1981: the content-12 publication (`qualified-stair-carry-v13`) loads through the actual Profiles loader
## and validator with the rooted-travel policy words. Data only: not the active catalog.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Carry := preload("res://data/underground/mole-worker/qualified-stair-carry-v13/catalog_source.gd")
const Wall := preload("res://data/underground/mole-worker/qualified-claw-wall-v12/catalog_source.gd")
const CARRY_WIRE: String = "res://data/underground/mole-worker/qualified-stair-carry-v13/mole-worker.ugprof"
const WALL_WIRE: String = "res://data/underground/mole-worker/qualified-claw-wall-v12/mole-worker.ugprof"
const TEMP_PATH: String = "user://stair-carry-negative.ugprof"
const CARRY_COUNTS: Vector3i = Vector3i(85, 637, 8)
const WALL_COUNTS: Vector3i = Vector3i(71, 595, 6)
const POLICY_BYTE: int = 97
const WOOD_CARRY_ROW: int = 32
const STONE_CARRY_ROW: int = 37
## Approach, descent, ascent, half-turn, retreat, back-up: their policy words and headings.
const LOADED_POLICIES: Array[int] = [Profiles.POLICY_ROOTED_TRAVEL, Profiles.POLICY_ROOTED_STAIR,
	Profiles.POLICY_ROOTED_STAIR, Profiles.POLICY_ROOTED_TURN, Profiles.POLICY_ROOTED_TRAVEL,
	Profiles.POLICY_ROOTED_BACKWARD]
const LOADED_YAWS: Array[int] = [0, 0, 32768, 0, 32768, 0]
var _carry: Profiles = null
var _wall: Profiles = null


func before_each() -> void:
	"""Both publications through the actual loader."""
	_carry = _loaded(CARRY_WIRE, Carry.WIRE_SHA, 12, CARRY_COUNTS)
	_wall = _loaded(WALL_WIRE, Wall.WIRE_SHA, 11, WALL_COUNTS)


func after_each() -> void:
	"""Drop both stores and the negative wire."""
	_carry = null
	_wall = null
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(TEMP_PATH)


func _store(counts: Vector3i) -> Profiles:
	"""One store sized for a publication."""
	var store: Profiles = Profiles.new()
	var packed: int = 2 * (counts.x * Profiles.PROFILE_WIRE_BYTES + counts.y * 28 + counts.z * 32 + 32)
	assert_equal(store.configure(counts.x, counts.y, counts.z, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	return store


func _loaded(path: String, digest: String, revision: int, counts: Vector3i) -> Profiles:
	"""One configured store with the publication loaded and validated."""
	var store: Profiles = _store(counts)
	assert_equal(store.load_file(path, digest, revision), &"", "actual loader and validator")
	return store


func _field(store: Profiles, field: int, row: int) -> int:
	"""One stored descriptor word."""
	return store._live.fields[field * store._profile_capacity + row]


func _policy(store: Profiles, row: int) -> int:
	"""One row's stored policy byte."""
	return store._live.flags[store._profile_capacity + row]


func _boxes(store: Profiles, row: int) -> Array:
	"""Every box word of one row."""
	var result: Array = []
	var first: int = _field(store, Profiles.F_FIRST_BOX, row)
	for box: int in range(first, first + _field(store, Profiles.F_BOX_COUNT, row)):
		for word: int in 7:
			result.append(store._live.boxes[word * store._box_capacity + box])
	return result


func _negative(row: int, offset: int, value: int, expected: StringName) -> void:
	"""One edited descriptor byte or word in a copy of the content-12 wire loads with `expected` (empty: admitted)."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(CARRY_WIRE)
	var at: int = 32 + 32 * CARRY_COUNTS.z + Profiles.PROFILE_WIRE_BYTES * row + offset
	if offset == POLICY_BYTE:
		bytes[at] = value
	else:
		bytes.encode_s32(at, value)
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var store: Profiles = _store(CARRY_COUNTS)
	assert_equal(store.load_file(TEMP_PATH, FileAccess.get_sha256(TEMP_PATH), 12), expected, "refusal")


func test_content_eleven_rows_are_unchanged() -> void:
	"""Rows 0-70 keep every word but the first-box index, and every box."""
	for row: int in WALL_COUNTS.x:
		for field: int in Profiles.I32_FIELDS:
			if field != Profiles.F_FIRST_BOX:
				assert_equal(_field(_carry, field, row), _field(_wall, field, row), "row %d field %d" % [row, field])
		assert_equal(_boxes(_carry, row), _boxes(_wall, row), "row %d boxes" % row)
		assert_equal(_policy(_carry, row), _policy(_wall, row), "row %d policy" % row)


func test_published_row_ids() -> void:
	"""The accessor names rows 71-84 and the two new sources."""
	assert_equal(Carry.STAIR_EMPTY_FLOOR_ROWS, PackedInt32Array([71, 72]), "empty floor end")
	assert_equal(Carry.STAIR_CARRY_WOOD_ROWS, PackedInt32Array([73, 74, 75, 76, 77, 78]), "wood")
	assert_equal(Carry.STAIR_CARRY_STONE_ROWS, PackedInt32Array([79, 80, 81, 82, 83, 84]), "stone")
	assert_equal(Carry.STAIR_CARRY_WOOD_SOURCE_SHA.length(), 64, "wood image digest")
	assert_equal(Carry.STAIR_CARRY_STONE_SOURCE_SHA.length(), 64, "stone image digest")


func _assert_loaded_rows(rows: PackedInt32Array, source: int, template: int) -> void:
	"""Each loaded row carries its template's unit on its own source, at its heading, with its policy word."""
	for at: int in rows.size():
		var row: int = rows[at]
		assert_equal(_field(_carry, Profiles.F_SOURCE, row), source, "row %d source" % row)
		assert_equal(_field(_carry, Profiles.F_MODE, row), Profiles.MODE_CARRY, "row %d carries" % row)
		assert_equal(_field(_carry, Profiles.F_CARGO, row), _field(_carry, Profiles.F_CARGO, template), "row %d unit" % row)
		assert_equal(_field(_carry, Profiles.F_TOOL, row), -1, "row %d holds no tool" % row)
		assert_equal(_field(_carry, Profiles.F_YAW_KIND, row), Profiles.YAW_EXACT, "row %d exact heading" % row)
		assert_equal(_field(_carry, Profiles.F_YAW, row), LOADED_YAWS[at], "row %d heading" % row)
		assert_equal(_field(_carry, Profiles.F_FAMILIES, row), 1, "row %d EARTH_TIMBER" % row)
		assert_equal(_policy(_carry, row), LOADED_POLICIES[at], "row %d policy word" % row)


func test_loaded_rows_carry_one_unit_with_a_rooted_policy() -> void:
	"""Rows 73-78 (wood, source 6) and 79-84 (stone, source 7)."""
	_assert_loaded_rows(Carry.STAIR_CARRY_WOOD_ROWS, 6, WOOD_CARRY_ROW)
	_assert_loaded_rows(Carry.STAIR_CARRY_STONE_ROWS, 7, STONE_CARRY_ROW)


func test_empty_floor_rows_walk_empty() -> void:
	"""Rows 71-72: source 6, WALK, no tool or cargo; the walk-off forward and the back-up backward, at yaw 0."""
	var policies: Array[int] = [Profiles.POLICY_ROOTED_TRAVEL, Profiles.POLICY_ROOTED_BACKWARD]
	for at: int in 2:
		var row: int = Carry.STAIR_EMPTY_FLOOR_ROWS[at]
		assert_equal(_field(_carry, Profiles.F_SOURCE, row), 6, "the wood image's body-only clips")
		assert_equal(_field(_carry, Profiles.F_MODE, row), Profiles.MODE_WALK, "walk")
		assert_equal(_field(_carry, Profiles.F_CARGO, row), -1, "no cargo")
		assert_equal(_field(_carry, Profiles.F_TOOL, row), -1, "no tool")
		assert_equal(_field(_carry, Profiles.F_YAW, row), 0, "facing down the trench")
		assert_equal(_policy(_carry, row), policies[at], "policy word")


func test_the_descent_row_holds_the_load_box() -> void:
	"""The derived wood descent box: one pitch down, the log 504 u ahead of the start root plus the 512 u advance."""
	var row: int = Carry.STAIR_CARRY_WOOD_ROWS[1]
	var first: int = _field(_carry, Profiles.F_FIRST_BOX, row)
	assert_equal(_field(_carry, Profiles.F_BOX_COUNT, row), 3, "body, stance, recovery")
	var body: Array = []
	for word: int in 7:
		body.append(_carry._live.boxes[word * _carry._box_capacity + first])
	assert_equal(body, [-424, -130, -949, 434, 850, 235, Profiles.BODY_HELD_LOAD], "derived body and load box")


func test_rooted_rows_are_never_selected_yet() -> void:
	"""Selection reads the rooted words as unknown until activation; no live caller can select them."""
	for row: int in [71, 73, 74, 79]:
		assert_equal(Profiles.selection_policy_leaf(_carry, row, 1, 12), -1, "row %d not selectable" % row)


func test_rooted_policy_predicates() -> void:
	"""The family is exactly 10-13; a rooted row may carry, every other explicit travel row walks."""
	assert_false(Profiles.is_rooted_policy(Profiles.POLICY_STAIR_TURN), "9 is the stair half-turn")
	assert_true(Profiles.is_rooted_policy(Profiles.POLICY_ROOTED_TRAVEL), "10")
	assert_true(Profiles.is_rooted_policy(Profiles.POLICY_ROOTED_TURN), "13")
	assert_false(Profiles.is_rooted_policy(Profiles.POLICY_ROOTED_TURN + 1), "14 is unknown")
	assert_equal(Profiles._policy_mode(Profiles.POLICY_ROOTED_STAIR, Profiles.MODE_CARRY), Profiles.MODE_CARRY, "rooted carry")
	assert_equal(Profiles._policy_mode(Profiles.POLICY_ROOTED_STAIR, Profiles.MODE_WALK), Profiles.MODE_WALK, "rooted walk")
	assert_equal(Profiles._policy_mode(Profiles.POLICY_STAIR, Profiles.MODE_CARRY), Profiles.MODE_WALK, "stair walks")
	assert_equal(Profiles._policy_mode(Profiles.POLICY_SOURCE_WORK, Profiles.MODE_WALK), Profiles.MODE_WORK, "work")
	assert_equal(Profiles._policy_mode(Profiles.POLICY_ASSEMBLY_HANDLING, Profiles.MODE_WALK), Profiles.MODE_WORK, "handling")


func test_a_rooted_carry_without_cargo_is_refused() -> void:
	"""A CARRY rooted row must name its unit."""
	_negative(Carry.STAIR_CARRY_WOOD_ROWS[1], Profiles.F_CARGO * 4, -1, &"PROFILE_POLICY_FORMAT")


func test_a_rooted_walk_with_cargo_is_refused() -> void:
	"""A WALK rooted row carries nothing."""
	_negative(Carry.STAIR_EMPTY_FLOOR_ROWS[0], Profiles.F_CARGO * 4, 60, &"PROFILE_POLICY_FORMAT")


func test_a_rooted_row_with_a_tool_is_refused() -> void:
	"""No rooted row holds a tool."""
	_negative(Carry.STAIR_CARRY_WOOD_ROWS[0], Profiles.F_TOOL * 4, 54, &"PROFILE_POLICY_FORMAT")


func test_a_rooted_row_turning_freely_is_refused() -> void:
	"""A rooted row keeps its exact heading."""
	_negative(Carry.STAIR_CARRY_WOOD_ROWS[1], Profiles.F_YAW_KIND * 4, Profiles.YAW_ALL, &"PROFILE_POLICY_FORMAT")


func test_a_rooted_row_in_work_mode_is_refused() -> void:
	"""A rooted row walks or carries; it never works."""
	_negative(Carry.STAIR_CARRY_WOOD_ROWS[1], Profiles.F_MODE * 4, Profiles.MODE_WORK, &"PROFILE_POLICY_FORMAT")


func test_the_stair_policy_still_refuses_cargo() -> void:
	"""The live stair rule is unchanged: a loaded row under POLICY_STAIR is refused."""
	_negative(Carry.STAIR_CARRY_WOOD_ROWS[1], POLICY_BYTE, Profiles.POLICY_STAIR, &"PROFILE_POLICY_FORMAT")


func test_a_short_step_cannot_carry() -> void:
	"""Only the rooted words admit CARRY; a loaded row under a short-step word is refused."""
	_negative(Carry.STAIR_CARRY_WOOD_ROWS[0], POLICY_BYTE, Profiles.POLICY_SHORT_FORWARD, &"PROFILE_POLICY_FORMAT")


func test_any_named_unit_may_be_carried() -> void:
	"""The rooted rule asks for a named unit, not a particular one: item 0 is a unit."""
	_negative(Carry.STAIR_CARRY_WOOD_ROWS[0], Profiles.F_CARGO * 4, 0, &"")


func test_two_rooted_rows_on_one_key_and_heading_are_ambiguous() -> void:
	"""The back-up under the approach's word shares its key and heading."""
	_negative(Carry.STAIR_CARRY_WOOD_ROWS[5], POLICY_BYTE, Profiles.POLICY_ROOTED_TRAVEL, &"PROFILE_AMBIGUOUS_KEY")


func test_a_policy_past_the_rooted_family_is_uncertified() -> void:
	"""14 is unknown."""
	_negative(Carry.STAIR_CARRY_WOOD_ROWS[0], POLICY_BYTE, Profiles.POLICY_ROOTED_TURN + 1,
		&"PROFILE_CERTIFICATE_REQUIRED")
