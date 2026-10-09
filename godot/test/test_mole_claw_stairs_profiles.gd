extends "res://test/framework/test_case.gd"
## ADR 1229: the content-10 publication (`qualified-claw-stairs-v11`) loads through the actual Profiles loader and
## validator, with the stair policy and the tread-fitting contact kind. Data only: not the active catalog.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Stairs := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const Approach := preload("res://data/underground/mole-worker/qualified-claw-approach-v10/catalog_source.gd")
const STAIRS_WIRE: String = "res://data/underground/mole-worker/qualified-claw-stairs-v11/mole-worker.ugprof"
const APPROACH_WIRE: String = "res://data/underground/mole-worker/qualified-claw-approach-v10/mole-worker.ugprof"
const TEMP_PATH: String = "user://claw-stairs-negative.ugprof"
const STAIRS_COUNTS: Vector3i = Vector3i(67, 547, 6)
const APPROACH_COUNTS: Vector3i = Vector3i(60, 517, 6)
const POLICY_BYTE: int = 97
var _stairs: Profiles = null
var _approach: Profiles = null


func before_each() -> void:
	"""Both publications through the actual loader."""
	_stairs = _loaded(STAIRS_WIRE, Stairs.WIRE_SHA, 10, STAIRS_COUNTS)
	_approach = _loaded(APPROACH_WIRE, Approach.WIRE_SHA, 9, APPROACH_COUNTS)


func after_each() -> void:
	"""Drop both stores and the negative wire."""
	_stairs = null
	_approach = null
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(TEMP_PATH)


func _store(counts: Vector3i) -> Profiles:
	"""One configured, empty store with the publication's exact capacity."""
	var store: Profiles = Profiles.new()
	var packed: int = 2 * (counts.x * Profiles.PROFILE_WIRE_BYTES + counts.y * 28 + counts.z * 32 + 32)
	assert_equal(store.configure(counts.x, counts.y, counts.z, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	return store


func _loaded(path: String, digest: String, revision: int, counts: Vector3i) -> Profiles:
	"""One store with the publication loaded and validated."""
	var store: Profiles = _store(counts)
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


func _same(new_row: int, old_row: int) -> void:
	"""Every word but the first-box index, and every box, equal content 9's row."""
	for field: int in Profiles.I32_FIELDS:
		if field != Profiles.F_FIRST_BOX:
			assert_equal(_field(_stairs, field, new_row), _field(_approach, field, old_row), "row %d field %d" % [new_row, field])
	assert_equal(_boxes(_stairs, new_row), _boxes(_approach, old_row), "row %d boxes" % new_row)


func _negative(row: int, offset: int, value: int, expected: StringName) -> void:
	"""One edited descriptor byte or word in a copy of the wire must be refused with `expected`."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(STAIRS_WIRE)
	var at: int = 32 + 32 * STAIRS_COUNTS.z + Profiles.PROFILE_WIRE_BYTES * row + offset
	if offset == POLICY_BYTE:
		bytes[at] = value
	else:
		bytes.encode_s32(at, value)
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var store: Profiles = _store(STAIRS_COUNTS)
	assert_equal(store.load_file(TEMP_PATH, FileAccess.get_sha256(TEMP_PATH), 10), expected, "refusal")


func test_content_nine_rows_are_kept_or_moved() -> void:
	"""Rows 0-50 are content 9's; its dig/tap rows 51-58 are 56-63 and its handling row 59 is 65."""
	for row: int in 51:
		_same(row, row)
	for at: int in 8:
		_same(56 + at, 51 + at)
	_same(Stairs.PAW_HANDLING_ROW, 59)
	assert_equal(Stairs.CLAW_DIG_ROWS, PackedInt32Array([56, 58, 60, 62]), "dig rows")
	assert_equal(Stairs.CLAW_TAP_ROWS, PackedInt32Array([57, 59, 61, 63]), "tap rows")


func test_stair_rows_carry_the_stair_policy() -> void:
	"""Descent (yaw 0), ascent (yaw 32768) and the half-turn (yaw 0): POLICY_STAIR, EARTH_TIMBER, no tool."""
	var expected: Dictionary = {Stairs.CLAW_DESCENT_ROW: 0, Stairs.CLAW_ASCENT_ROW: 32768, Stairs.CLAW_TURN_ROW: 0}
	for row: int in expected:
		var policy: int = Profiles.POLICY_STAIR_TURN if row == Stairs.CLAW_TURN_ROW else Profiles.POLICY_STAIR
		assert_equal(Profiles.selection_policy_leaf(_stairs, row, 1, 10), policy, "stair policy")
		assert_equal(_field(_stairs, Profiles.F_FAMILIES, row), 1, "EARTH_TIMBER")
		assert_equal(_field(_stairs, Profiles.F_YAW, row), expected[row], "heading")
		assert_equal(_field(_stairs, Profiles.F_MODE, row), Profiles.MODE_WALK, "walk mode")
		assert_equal(_field(_stairs, Profiles.F_SOURCE, row), 4, "the Frontier source")


func test_short_steps_and_tread_rows() -> void:
	"""Short steps on the ground; the tread fitting row has no contact boxes; the tread handling row is source 5."""
	assert_equal(Profiles.selection_policy_leaf(_stairs, Stairs.CLAW_STEP_BACK_ROW, 1, 10), Profiles.POLICY_SHORT_BACKWARD, "back")
	assert_equal(Profiles.selection_policy_leaf(_stairs, Stairs.CLAW_STEP_FORWARD_ROW, 1, 10), Profiles.POLICY_SHORT_FORWARD, "forward")
	assert_equal(_field(_stairs, Profiles.F_CONTACT_KIND, Stairs.CLAW_TREAD_TAP_ROW), Profiles.CONTACT_TREAD_FIT, "tread fit")
	assert_equal(_field(_stairs, Profiles.F_BOX_COUNT, Stairs.CLAW_TREAD_TAP_ROW), 8, "body, stance, recovery, approach, stroke")
	assert_equal(_field(_stairs, Profiles.F_SOURCE, Stairs.PAW_TREAD_HANDLING_ROW), 5, "paw source")
	assert_equal(Profiles.selection_policy_leaf(_stairs, Stairs.PAW_TREAD_HANDLING_ROW, 1, 10),
		Profiles.POLICY_ASSEMBLY_HANDLING, "handling")


func test_a_stair_row_without_a_connector_family_is_refused() -> void:
	"""POLICY_STAIR needs a family mask."""
	_negative(Stairs.CLAW_DESCENT_ROW, Profiles.F_FAMILIES * 4, 0, &"PROFILE_POLICY_FORMAT")


func test_a_tread_fit_with_anchor_contact_is_refused() -> void:
	"""Row 64 with an anchor-and-patch contact kind lacks its point and patch."""
	_negative(Stairs.CLAW_TREAD_TAP_ROW, Profiles.F_CONTACT_KIND * 4, Profiles.CONTACT_ANCHOR_AND_PATCH,
		&"PROFILE_ROLE_MISSING")


func test_an_unknown_policy_is_refused() -> void:
	"""Policies above POLICY_STAIR_TURN stay uncertified, and the turn under the descent's policy is ambiguous."""
	_negative(Stairs.CLAW_TURN_ROW, POLICY_BYTE, Profiles.POLICY_STAIR_TURN + 1, &"PROFILE_CERTIFICATE_REQUIRED")
	_negative(Stairs.CLAW_TURN_ROW, POLICY_BYTE, Profiles.POLICY_STAIR, &"PROFILE_AMBIGUOUS_KEY")
