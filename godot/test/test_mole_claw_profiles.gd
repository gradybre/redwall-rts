extends "res://test/framework/test_case.gd"
## ADR 1217 step 4: the content-7 publication (`qualified-claw-v8`) loads through the actual Profiles loader and
## validator. Data only: it is not the active catalog, and no Routes, World or presentation permission follows.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Claw := preload("res://data/underground/mole-worker/qualified-claw-v8/catalog_source.gd")
const Stone := preload("res://data/underground/mole-worker/qualified-stone-v7/catalog_source.gd")
const CLAW_WIRE: String = "res://data/underground/mole-worker/qualified-claw-v8/mole-worker.ugprof"
const STONE_WIRE: String = "res://data/underground/mole-worker/qualified-stone-v7/mole-worker.ugprof"
const CLAW_COUNTS: Vector3i = Vector3i(51, 472, 5)
const STONE_COUNTS: Vector3i = Vector3i(42, 377, 4)
const CLAW_SOURCE: int = 4
const DIG_ROWS: PackedInt32Array = [42, 45, 47, 49]
const TAP_ROWS: PackedInt32Array = [43, 46, 48, 50]
const HANDLING_ROW: int = 44
const YAWS: PackedInt32Array = [0, 16384, 32768, 49152]
var _claw: Profiles = null
var _stone: Profiles = null


func before_each() -> void:
	"""Both publications through the actual loader, each in its own exact capacity."""
	_claw = _loaded(CLAW_WIRE, Claw.WIRE_SHA, 7, CLAW_COUNTS)
	_stone = _loaded(STONE_WIRE, Stone.WIRE_SHA, 6, STONE_COUNTS)


func after_each() -> void:
	"""Drop both stores."""
	_claw = null
	_stone = null


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


func test_content_seven_header_and_sources() -> void:
	"""Revision 7, 51 rows, 472 boxes and 5 sources: sources 0/1 unchanged, 2-4 the step-3 images."""
	assert_equal(_claw.content_revision(), 7, "content revision")
	assert_equal(Array(_claw._live.header), [7, 51, 472, 5], "header")
	assert_equal(_claw._live.sources.slice(0, 64), _stone._live.sources.slice(0, 64), "pick and handling sources")
	assert_equal(_claw._live.sources.slice(64, 96).hex_encode(), Claw.HAUL_SOURCE_SHA, "wood v10")
	assert_equal(_claw._live.sources.slice(96, 128).hex_encode(), Claw.STONE_SOURCE_SHA, "stone v10")
	assert_equal(_claw._live.sources.slice(128, 160).hex_encode(), Claw.CLAW_SOURCE_SHA, "claw/paw image")


func test_published_rows_keep_their_words() -> void:
	"""Rows 0-41 keep every descriptor word except their first-box index; IDs never move."""
	for row: int in 42:
		for field: int in Profiles.I32_FIELDS:
			if field == Profiles.F_FIRST_BOX:
				continue
			assert_equal(_field(_claw, field, row), _field(_stone, field, row), "row %d field %d" % [row, field])


func test_claw_rows_are_tool_free_work_rows() -> void:
	"""Dig and tap rows: BUILD WORK at the four exact headings on source 4, no tool, source-work policy."""
	for at: int in 4:
		for row: int in [DIG_ROWS[at], TAP_ROWS[at]]:
			assert_equal(_field(_claw, Profiles.F_SOURCE, row), CLAW_SOURCE, "claw source")
			assert_equal(_field(_claw, Profiles.F_MODE, row), Profiles.MODE_WORK, "WORK")
			assert_equal(_field(_claw, Profiles.F_TOOL, row), -1, "no tool")
			assert_equal(_field(_claw, Profiles.F_YAW, row), YAWS[at], "heading")
			assert_equal(_field(_claw, Profiles.F_CONTACT_KIND, row), Profiles.CONTACT_ANCHOR_AND_PATCH, "contact")
			assert_equal(Profiles.selection_policy_leaf(_claw, row, 1, 7), Profiles.POLICY_SOURCE_WORK, "policy")


func test_paw_handling_row() -> void:
	"""The paw handling row keeps row 29's policy and contact kind with no tool."""
	assert_equal(_field(_claw, Profiles.F_SOURCE, HANDLING_ROW), CLAW_SOURCE, "claw source")
	assert_equal(_field(_claw, Profiles.F_TOOL, HANDLING_ROW), -1, "no tool")
	assert_equal(_field(_claw, Profiles.F_CONTACT_KIND, HANDLING_ROW), Profiles.CONTACT_ASSEMBLY_PALM, "palm")
	assert_equal(Profiles.selection_policy_leaf(_claw, HANDLING_ROW, 1, 7), Profiles.POLICY_ASSEMBLY_HANDLING,
		"assembly handling")


func test_corrected_stand_and_walk_sweep() -> void:
	"""Rows 30/31's first box is the corrected 712 u all-yaw body sweep (651 in content 6)."""
	for row: int in [30, 31]:
		var first: int = _field(_claw, Profiles.F_FIRST_BOX, row)
		var old: int = _field(_stone, Profiles.F_FIRST_BOX, row)
		assert_equal(_claw._live.boxes[first], -712, "corrected sweep x0")
		assert_equal(_stone._live.boxes[old], -651, "published sweep x0")
