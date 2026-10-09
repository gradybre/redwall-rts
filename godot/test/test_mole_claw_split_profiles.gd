extends "res://test/framework/test_case.gd"
## ADR 1217 step 4c: the content-8 publication (`qualified-claw-split-v9`) loads through the actual Profiles loader and
## validator. Data only: it is not the active catalog, and no Routes, World or presentation permission follows.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Split := preload("res://data/underground/mole-worker/qualified-claw-split-v9/catalog_source.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-v8/catalog_source.gd")
const SPLIT_WIRE: String = "res://data/underground/mole-worker/qualified-claw-split-v9/mole-worker.ugprof"
const CLAW_WIRE: String = "res://data/underground/mole-worker/qualified-claw-v8/mole-worker.ugprof"
const TEMP_PATH: String = "user://claw-split-ambiguous-walk.ugprof"
const SPLIT_COUNTS: Vector3i = Vector3i(52, 477, 6)
const CLAW_COUNTS: Vector3i = Vector3i(51, 472, 5)
const CLAW_SOURCE: int = 4
const PAW_SOURCE: int = 5
const WALK_ROW: int = 42
const WORK_ROWS: PackedInt32Array = [43, 44, 45, 46, 47, 48, 49, 50]
const CONTENT_SEVEN_WORK_ROWS: PackedInt32Array = [42, 43, 45, 46, 47, 48, 49, 50]
const WORK_YAWS: PackedInt32Array = [0, 0, 16384, 16384, 32768, 32768, 49152, 49152]
const HANDLING_ROW: int = 51
const CONTENT_SEVEN_HANDLING_ROW: int = 44
const POLICY_BYTE: int = 97
var _split: Profiles = null
var _claw: Profiles = null


func before_each() -> void:
	"""Both publications through the actual loader, each in its own exact capacity."""
	_split = _loaded(SPLIT_WIRE, Split.WIRE_SHA, 8, SPLIT_COUNTS)
	_claw = _loaded(CLAW_WIRE, Claw.WIRE_SHA, 7, CLAW_COUNTS)


func after_each() -> void:
	"""Drop both stores and this test's negative wire."""
	_split = null
	_claw = null
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
	"""Every box word of one row, in order."""
	var result: Array = []
	var first: int = _field(store, Profiles.F_FIRST_BOX, row)
	for box: int in range(first, first + _field(store, Profiles.F_BOX_COUNT, row)):
		for word: int in 7:
			result.append(store._live.boxes[word * store._box_capacity + box])
	return result


func test_content_eight_header_and_sources() -> void:
	"""Revision 8, 52 rows, 477 boxes, 6 sources: sources 0-3 are content 7's, 4/5 the split images."""
	assert_equal(_split.content_revision(), 8, "content revision")
	assert_equal(Array(_split._live.header), [8, 52, 477, 6], "header")
	assert_equal(_split._live.sources.slice(0, 128), _claw._live.sources.slice(0, 128), "sources 0-3")
	assert_equal(_split._live.sources.slice(128, 160).hex_encode(), Split.CLAW_SOURCE_SHA, "claw image")
	assert_equal(_split._live.sources.slice(160, 192).hex_encode(), Split.PAW_SOURCE_SHA, "paw-handling image")


func test_published_rows_keep_their_words_and_boxes() -> void:
	"""Rows 0-41 keep every descriptor word except their first-box index, and every box; IDs never move."""
	for row: int in 42:
		for field: int in Profiles.I32_FIELDS:
			if field == Profiles.F_FIRST_BOX:
				continue
			assert_equal(_field(_split, field, row), _field(_claw, field, row), "row %d field %d" % [row, field])
		assert_equal(_boxes(_split, row), _boxes(_claw, row), "row %d boxes" % row)


func test_source_four_walk_is_tool_free_canonical_ground() -> void:
	"""Row 42: YAW_ALL WALK on source 4, no tool, the canonical-ground policy, and the corrected 712 u sweep."""
	assert_equal(_field(_split, Profiles.F_SOURCE, WALK_ROW), CLAW_SOURCE, "claw source")
	assert_equal(_field(_split, Profiles.F_MODE, WALK_ROW), Profiles.MODE_WALK, "WALK")
	assert_equal(_field(_split, Profiles.F_YAW_KIND, WALK_ROW), Profiles.YAW_ALL, "all headings")
	assert_equal(_field(_split, Profiles.F_TOOL, WALK_ROW), -1, "no tool")
	assert_equal(Profiles.selection_policy_leaf(_split, WALK_ROW, 1, 8), Profiles.POLICY_CANONICAL_GROUND, "policy")
	assert_equal(_boxes(_split, WALK_ROW), _boxes(_claw, 31), "the derived boxes equal corrected row 31's")


func test_claw_work_rows_are_re_homed_on_source_four() -> void:
	"""Dig and tap rows: content 7's words and boxes on source 4, at the four exact headings."""
	for at: int in WORK_ROWS.size():
		var row: int = WORK_ROWS[at]
		assert_equal(_field(_split, Profiles.F_SOURCE, row), CLAW_SOURCE, "claw source")
		assert_equal(_field(_split, Profiles.F_YAW, row), WORK_YAWS[at], "heading")
		assert_equal(_field(_split, Profiles.F_TOOL, row), -1, "no tool")
		assert_equal(Profiles.selection_policy_leaf(_split, row, 1, 8), Profiles.POLICY_SOURCE_WORK, "policy")
		assert_equal(_field(_split, Profiles.F_CONTACT_KIND, row), Profiles.CONTACT_ANCHOR_AND_PATCH, "contact")
		assert_equal(_boxes(_split, row), _boxes(_claw, CONTENT_SEVEN_WORK_ROWS[at]), "content 7's boxes")


func test_paw_handling_row_is_on_its_own_source() -> void:
	"""Row 51 holds content 7's handling words and boxes on source 5, distinct from the Frontier source 4."""
	assert_equal(_field(_split, Profiles.F_SOURCE, HANDLING_ROW), PAW_SOURCE, "paw-handling source")
	assert_equal(_field(_split, Profiles.F_CONTACT_KIND, HANDLING_ROW), Profiles.CONTACT_ASSEMBLY_PALM, "palm")
	assert_equal(Profiles.selection_policy_leaf(_split, HANDLING_ROW, 1, 8), Profiles.POLICY_ASSEMBLY_HANDLING,
		"assembly handling")
	assert_equal(_boxes(_split, HANDLING_ROW), _boxes(_claw, CONTENT_SEVEN_HANDLING_ROW), "content 7's boxes")


func test_an_automatic_source_four_walk_is_refused_as_ambiguous() -> void:
	"""The same row with row 31's automatic policy duplicates its key, which the loader refuses."""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SPLIT_WIRE)
	var at: int = 32 + 32 * SPLIT_COUNTS.z + Profiles.PROFILE_WIRE_BYTES * WALK_ROW + POLICY_BYTE
	assert_equal(bytes[at], Profiles.POLICY_CANONICAL_GROUND, "published policy byte")
	bytes[at] = Profiles.POLICY_AUTOMATIC
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var store: Profiles = _store(SPLIT_COUNTS)
	assert_equal(store.load_file(TEMP_PATH, FileAccess.get_sha256(TEMP_PATH), 8), &"PROFILE_AMBIGUOUS_KEY",
		"an automatic tool-free WALK on source 4 is row 31's key")
	assert_equal(store.content_revision(), 0, "the refused wire publishes nothing")
