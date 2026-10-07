extends "res://test/framework/test_case.gd"
## ADR 1217 step 4e: the content-9 publication (`qualified-claw-approach-v10`) loads through the actual Profiles
## loader and validator. Data only: it is not the active catalog, and no Routes or World permission follows.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Approach := preload("res://data/underground/mole-worker/qualified-claw-approach-v10/catalog_source.gd")
const Split := preload("res://data/underground/mole-worker/qualified-claw-split-v9/catalog_source.gd")
const APPROACH_WIRE: String = "res://data/underground/mole-worker/qualified-claw-approach-v10/mole-worker.ugprof"
const SPLIT_WIRE: String = "res://data/underground/mole-worker/qualified-claw-split-v9/mole-worker.ugprof"
const APPROACH_COUNTS: Vector3i = Vector3i(60, 517, 6)
const SPLIT_COUNTS: Vector3i = Vector3i(52, 477, 6)
const YAWS: PackedInt32Array = [0, 16384, 32768, 49152]
const NARROW_BODY: Array = [-485, 0, -521, 479, 930, 412, Profiles.BODY_HELD_LOAD]
var _approach: Profiles = null
var _split: Profiles = null


func before_each() -> void:
	"""Both publications through the actual loader, each in its own exact capacity."""
	_approach = _loaded(APPROACH_WIRE, Approach.WIRE_SHA, 9, APPROACH_COUNTS)
	_split = _loaded(SPLIT_WIRE, Split.WIRE_SHA, 8, SPLIT_COUNTS)


func after_each() -> void:
	"""Drop both stores."""
	_approach = null
	_split = null


func _loaded(path: String, digest: String, revision: int, counts: Vector3i) -> Profiles:
	"""One store with the publication loaded and validated."""
	var store: Profiles = Profiles.new()
	var packed: int = 2 * (counts.x * Profiles.PROFILE_WIRE_BYTES + counts.y * 28 + counts.z * 32 + 32)
	assert_equal(store.configure(counts.x, counts.y, counts.z, packed + Profiles.CONTROL_RESERVE), &"", "capacity")
	assert_equal(store.load_file(path, digest, revision), &"", "actual loader and validator")
	return store


func _field(store: Profiles, field: int, row: int) -> int:
	"""One stored descriptor word."""
	return store._live.fields[field * store._profile_capacity + row]


func _boxes(store: Profiles, row: int) -> Array:
	"""Every box word of one row, in order."""
	var result: Array = []
	var first: int = _field(store, Profiles.F_FIRST_BOX, row)
	for box: int in range(first, first + _field(store, Profiles.F_BOX_COUNT, row)):
		for word: int in 7:
			result.append(store._live.boxes[word * store._box_capacity + box])
	return result


func _same_row(new_row: int, old_row: int) -> void:
	"""Every descriptor word except the first-box index, and every box, match content 8's row."""
	for field: int in Profiles.I32_FIELDS:
		if field != Profiles.F_FIRST_BOX:
			assert_equal(_field(_approach, field, new_row), _field(_split, field, old_row),
				"row %d field %d" % [new_row, field])
	assert_equal(_boxes(_approach, new_row), _boxes(_split, old_row), "row %d boxes" % new_row)


func test_content_nine_header_and_sources() -> void:
	"""Revision 9, 60 rows, 517 boxes and content 8's six sources."""
	assert_equal(Array(_approach._live.header), [9, 60, 517, 6], "header")
	assert_equal(_approach._live.sources, _split._live.sources, "sources unchanged")


func test_rows_kept_and_moved_unchanged() -> void:
	"""Rows 0-42 are content 8's; content 8's rows 43-51 are rows 51-59, words and boxes unchanged."""
	for row: int in 43:
		_same_row(row, row)
	for at: int in 9:
		_same_row(51 + at, 43 + at)


func test_narrow_rows_are_exact_heading_source_walks() -> void:
	"""Approach and retreat: tool-free source-4 WALK at each exact heading with the narrow derived body."""
	for at: int in 4:
		for pair: Array in [[Approach.CLAW_APPROACH_ROWS[at], Profiles.POLICY_READY_FORWARD],
				[Approach.CLAW_RETREAT_ROWS[at], Profiles.POLICY_READY_BACKWARD]]:
			var row: int = pair[0]
			assert_equal(_field(_approach, Profiles.F_SOURCE, row), 4, "claw source")
			assert_equal(_field(_approach, Profiles.F_MODE, row), Profiles.MODE_WALK, "WALK")
			assert_equal(_field(_approach, Profiles.F_YAW_KIND, row), Profiles.YAW_EXACT, "exact heading")
			assert_equal(_field(_approach, Profiles.F_YAW, row), YAWS[at], "heading")
			assert_equal(_field(_approach, Profiles.F_TOOL, row), -1, "no tool")
			assert_equal(Profiles.selection_policy_leaf(_approach, row, 1, 9), pair[1], "policy")
	assert_equal(_boxes(_approach, Approach.CLAW_APPROACH_ROWS[0]).slice(0, 7), NARROW_BODY, "narrow body at yaw 0")
	assert_equal(_boxes(_approach, Approach.CLAW_APPROACH_ROWS[0]), _boxes(_approach, Approach.CLAW_RETREAT_ROWS[0]),
		"retreat shares every box")


func test_accessor_rows_and_fade_window() -> void:
	"""The accessor names the moved rows and Brendan's fade window."""
	assert_equal(_field(_approach, Profiles.F_SOURCE, Approach.PAW_HANDLING_ROW), 5, "paw handling on source 5")
	for row: int in Approach.CLAW_DIG_ROWS:
		assert_equal(_field(_approach, Profiles.F_CONTACT_KIND, row), Profiles.CONTACT_ANCHOR_AND_PATCH, "dig contact")
	assert_equal([Approach.CLAW_FADE_BLOCKED_FIRST, Approach.CLAW_FADE_BLOCKED_LAST, Approach.CLAW_FADE_RESUME_KEY],
		[28, 37, 38], "fade only from clear frames")
	assert_equal(Approach.CLAW_FADE_RESUME_KEY < Approach.CLAW_WALK_KEYS - 1, true, "resume key inside the walk")
