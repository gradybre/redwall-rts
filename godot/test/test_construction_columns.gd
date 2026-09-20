extends "res://test/framework/test_case.gd"
## Independent functional tests of the pure Construction.Columns row family and
## Construction.columns_refusal() (CONSTRUCTION-S4-VALIDATE-R01v2, ADR 0186), against the
## accepted contract and witness-plan-v2.json, transcribed literally as an independent oracle.
## Expected codes are raw StringName literals; declared work/bill/worker facts used to build
## the valid-tuple matrix are transcribed independently (T_* below), never read from
## Construction's own COLUMN_* gate arrays or derived from calling columns_refusal itself.

const Construction := preload("res://scripts/core/construction.gd")

const OWNER_CAPACITY: int = 82944

const FIELD_NAMES: Array[String] = [
	"present", "material_container_slot", "material_container_generation", "assigned_count",
	"max_workers", "refund_policy", "remaining_mwu", "paused", "work_begun", "ref_slot",
	"ref_generation", "subject_slot", "subject_generation", "purpose", "type_id", "phase",
]

const FIELD_TYPE_CODES: Dictionary = {
	"present": TYPE_PACKED_BYTE_ARRAY, "material_container_slot": TYPE_PACKED_INT32_ARRAY,
	"material_container_generation": TYPE_PACKED_INT32_ARRAY,
	"assigned_count": TYPE_PACKED_INT32_ARRAY, "max_workers": TYPE_PACKED_INT32_ARRAY,
	"refund_policy": TYPE_PACKED_INT32_ARRAY, "remaining_mwu": TYPE_PACKED_INT64_ARRAY,
	"paused": TYPE_PACKED_BYTE_ARRAY, "work_begun": TYPE_PACKED_BYTE_ARRAY,
	"ref_slot": TYPE_PACKED_INT32_ARRAY, "ref_generation": TYPE_PACKED_INT32_ARRAY,
	"subject_slot": TYPE_PACKED_INT32_ARRAY, "subject_generation": TYPE_PACKED_INT32_ARRAY,
	"purpose": TYPE_PACKED_INT32_ARRAY, "type_id": TYPE_PACKED_INT32_ARRAY,
	"phase": TYPE_PACKED_INT32_ARRAY,
}

const SHAPE_LENGTHS: Array[int] = [0, 82943, 82945]
const ROW_POSITIONS: Array[int] = [0, 1, 41471, 41472, 82943]
const FLAG_FIELDS: Array[String] = ["present", "paused", "work_begun"]
const FLAG_INVALID_VALUES: Array[int] = [2, 255]
const FLAG_POSITIONS: Array[int] = [0, 1, 41472, 82943]

# --- witness-plan-v2.json "bases", transcribed literally ---------------------------------------

const BASE_CLEAR: Dictionary = {
	"present": 0, "material_container_slot": -1, "material_container_generation": 0,
	"assigned_count": 0, "max_workers": 0, "refund_policy": 0, "remaining_mwu": 0,
	"paused": 0, "work_begun": 0, "ref_slot": -1, "ref_generation": 0, "subject_slot": -1,
	"subject_generation": 0, "purpose": 0, "type_id": -1, "phase": 0,
}
const BASE_LIVE: Dictionary = {
	"present": 1, "material_container_slot": -1, "material_container_generation": 0,
	"assigned_count": 0, "max_workers": 4, "refund_policy": 0, "remaining_mwu": 60000,
	"paused": 0, "work_begun": 0, "ref_slot": 0, "ref_generation": 1, "subject_slot": 1,
	"subject_generation": 1, "purpose": 0, "type_id": 19, "phase": 0,
}
const BASE_RETIRED: Dictionary = {
	"present": 0, "material_container_slot": -1, "material_container_generation": 0,
	"assigned_count": 0, "max_workers": 4, "refund_policy": 1, "remaining_mwu": 0,
	"paused": 0, "work_begun": 0, "ref_slot": -1, "ref_generation": 0, "subject_slot": -1,
	"subject_generation": 0, "purpose": 0, "type_id": 19, "phase": 3,
}

# --- witness-plan-v2.json single_fault_cases, transcribed literally (40 entries) ---------------

const SINGLE_FAULT_CASES: Array[Dictionary] = [
	{"id": "enum-purpose", "base": "live", "changes": {"purpose": 4}, "expected": "COLUMN_ENUM"},
	{"id": "enum-phase", "base": "live", "changes": {"phase": 5}, "expected": "COLUMN_ENUM"},
	{"id": "enum-refund_policy", "base": "live", "changes": {"refund_policy": 3},
		"expected": "COLUMN_ENUM"},
	{"id": "negative-remaining_mwu", "base": "live", "changes": {"remaining_mwu": -1},
		"expected": "COLUMN_VALUE"},
	{"id": "negative-assigned_count", "base": "live", "changes": {"assigned_count": -1},
		"expected": "COLUMN_VALUE"},
	{"id": "negative-max_workers", "base": "live", "changes": {"max_workers": -1},
		"expected": "COLUMN_VALUE"},
	{"id": "negative-type_id", "base": "live", "changes": {"type_id": -2},
		"expected": "COLUMN_VALUE"},
	{"id": "half-null-ref", "base": "live", "changes": {"ref_slot": -1, "ref_generation": 1},
		"expected": "COLUMN_REF"},
	{"id": "zero-generation-ref", "base": "live", "changes": {"ref_slot": 0, "ref_generation": 0},
		"expected": "COLUMN_REF"},
	{"id": "half-null-subject", "base": "live",
		"changes": {"subject_slot": -1, "subject_generation": 1}, "expected": "COLUMN_REF"},
	{"id": "zero-generation-subject", "base": "live",
		"changes": {"subject_slot": 0, "subject_generation": 0}, "expected": "COLUMN_REF"},
	{"id": "half-null-material_container", "base": "live",
		"changes": {"material_container_slot": -1, "material_container_generation": 1},
		"expected": "COLUMN_REF"},
	{"id": "zero-generation-material_container", "base": "live",
		"changes": {"material_container_slot": 0, "material_container_generation": 0},
		"expected": "COLUMN_REF"},
	{"id": "directory-overflow-ref", "base": "live", "changes": {"ref_slot": 352418},
		"expected": "COLUMN_REF"},
	{"id": "directory-overflow-subject", "base": "live", "changes": {"subject_slot": 352418},
		"expected": "COLUMN_REF"},
	{"id": "inactive-self", "base": "live", "changes": {"present": 0}, "expected": "COLUMN_FREE"},
	{"id": "clear-retains-purpose", "base": "clear", "changes": {"purpose": 1},
		"expected": "COLUMN_FREE"},
	{"id": "clear-retains-phase", "base": "clear", "changes": {"phase": 1},
		"expected": "COLUMN_FREE"},
	{"id": "active-null-self", "base": "live", "changes": {"ref_slot": -1, "ref_generation": 0},
		"expected": "COLUMN_FREE"},
	{"id": "active-null-subject", "base": "live",
		"changes": {"subject_slot": -1, "subject_generation": 0}, "expected": "COLUMN_FREE"},
	{"id": "building-type-overflow", "base": "live", "changes": {"type_id": 30},
		"expected": "COLUMN_TYPE"},
	{"id": "furniture-type-overflow", "base": "live", "changes": {"purpose": 2, "type_id": 9},
		"expected": "COLUMN_TYPE"},
	{"id": "upgrade-nonmember", "base": "live", "changes": {"purpose": 1, "type_id": 0},
		"expected": "COLUMN_TYPE"},
	{"id": "live-sentinel-type", "base": "live", "changes": {"type_id": -1},
		"expected": "COLUMN_TYPE"},
	{"id": "wrong-max-workers", "base": "live", "changes": {"max_workers": 3},
		"expected": "COLUMN_WORKERS"},
	{"id": "assigned-over-cap", "base": "live", "changes": {"assigned_count": 5},
		"expected": "COLUMN_WORKERS"},
	{"id": "paused-assigned", "base": "live", "changes": {"paused": 1, "assigned_count": 1},
		"expected": "COLUMN_WORKERS"},
	{"id": "refunding-assigned", "base": "live", "changes": {"phase": 4, "assigned_count": 1},
		"expected": "COLUMN_WORKERS"},
	{"id": "unbegun-partial-policy", "base": "live", "changes": {"refund_policy": 1},
		"expected": "COLUMN_POLICY"},
	{"id": "demolition-full-policy", "base": "live",
		"changes": {"purpose": 3, "phase": 1, "remaining_mwu": 15000}, "expected": "COLUMN_POLICY"},
	{"id": "awaiting-begun", "base": "live", "changes": {"work_begun": 1, "refund_policy": 1},
		"expected": "COLUMN_PHASE"},
	{"id": "working-zero", "base": "live",
		"changes": {"phase": 2, "work_begun": 1, "refund_policy": 1, "remaining_mwu": 0},
		"expected": "COLUMN_PHASE"},
	{"id": "done-positive", "base": "live",
		"changes": {"phase": 3, "work_begun": 1, "refund_policy": 1, "remaining_mwu": 1},
		"expected": "COLUMN_PHASE"},
	{"id": "refund-unbegun-short-work", "base": "live",
		"changes": {"phase": 4, "remaining_mwu": 59999}, "expected": "COLUMN_PHASE"},
	{"id": "empty-build-awaiting", "base": "live",
		"changes": {"type_id": 6, "remaining_mwu": 2000}, "expected": "COLUMN_PHASE"},
	{"id": "demolition-awaiting", "base": "live",
		"changes": {"purpose": 3, "refund_policy": 2, "remaining_mwu": 15000},
		"expected": "COLUMN_PHASE"},
	{"id": "retired-ready", "base": "retired", "changes": {"phase": 1, "refund_policy": 0},
		"expected": "COLUMN_PHASE"},
	{"id": "retired-demolition-full", "base": "retired",
		"changes": {"purpose": 3, "refund_policy": 0}, "expected": "COLUMN_POLICY"},
	{"id": "retired-completed-full", "base": "retired", "changes": {"refund_policy": 0},
		"expected": "COLUMN_POLICY"},
	{"id": "retired-progress", "base": "retired", "changes": {"remaining_mwu": 1},
		"expected": "COLUMN_FREE"},
]

# --- independent, ordered two-fault gate-collision pairs (F5) -----------------------------------
# Each pair's baseline is the LATER gate's fault alone; the combined image adds the EARLIER
# gate's fault on top, preserving the later fault, and must show the earlier gate wins.

const GATE_COLLISION_PAIRS: Array[Dictionary] = [
	{"id": "enum-before-value", "base": "live", "later": {"remaining_mwu": -1},
		"earlier": {"purpose": 4}, "later_expected": "COLUMN_VALUE", "earlier_expected": "COLUMN_ENUM"},
	{"id": "value-before-ref", "base": "live", "later": {"ref_slot": 0, "ref_generation": 0},
		"earlier": {"remaining_mwu": -1}, "later_expected": "COLUMN_REF",
		"earlier_expected": "COLUMN_VALUE"},
	{"id": "ref-before-free", "base": "clear", "later": {"purpose": 1},
		"earlier": {"ref_slot": 0, "ref_generation": 0}, "later_expected": "COLUMN_FREE",
		"earlier_expected": "COLUMN_REF"},
	{"id": "free-before-type", "base": "live", "later": {"type_id": 30}, "earlier": {"present": 0},
		"later_expected": "COLUMN_TYPE", "earlier_expected": "COLUMN_FREE"},
	{"id": "type-before-workers", "base": "live", "later": {"max_workers": 3},
		"earlier": {"type_id": 30}, "later_expected": "COLUMN_WORKERS",
		"earlier_expected": "COLUMN_TYPE"},
	{"id": "workers-before-policy", "base": "live", "later": {"refund_policy": 1},
		"earlier": {"assigned_count": 5}, "later_expected": "COLUMN_POLICY",
		"earlier_expected": "COLUMN_WORKERS"},
	{"id": "policy-before-phase", "base": "live", "later": {"work_begun": 1, "refund_policy": 1},
		"earlier": {"refund_policy": 0}, "later_expected": "COLUMN_PHASE",
		"earlier_expected": "COLUMN_POLICY"},
]

# --- independent frozen source facts, transcribed from frozen-source-facts.json ----------------

const T_BUILDING_WORK: Array[int] = [
	180000, 720000, 480000, 900000, 120000, 480000, 2000, 240000, 12000, 240000, 240000, 90000,
	2400000, 1000000, 600000, 180000, 240000, 720000, 300000, 60000, 6000, 480000, 240000,
	1200000, 240000, 30000, 480000, 240000, 180000, 720000,
]
const T_BUILDING_BILL_PAIRS: Array[int] = [
	2, 3, 3, 2, 1, 2, 0, 2, 1, 2, 2, 2, 3, 3, 3, 2, 2, 2, 2, 1, 1, 3, 2, 3, 2, 1, 3, 2, 2, 3,
]
const T_FURNITURE_WORK: Array[int] = [20000, 12000, 60000, 12000, 8000, 60000, 24000, 10000, 16000]
const T_FURNITURE_BILL_PAIRS: Array[int] = [2, 2, 1, 1, 1, 3, 2, 1, 1]
const T_UPGRADE_IDS: Array[int] = [5, 12, 23, 29]
const T_UPGRADE_WORK: Array[int] = [600000, 1200000, 1200000, 720000]
const T_UPGRADE_BILL_PAIRS: Array[int] = [2, 3, 3, 2]
const T_MAX_WORKERS: int = 4

const P_BUILD: int = 0
const P_UPGRADE: int = 1
const P_FURNITURE: int = 2
const P_DEMOLISH: int = 3
const PH_AWAITING: int = 0
const PH_READY: int = 1
const PH_WORKING: int = 2
const PH_WORK_DONE: int = 3
const PH_REFUNDING: int = 4
const R_FULL: int = 0
const R_PARTIAL: int = 1
const R_DEMOLITION: int = 2


# --- fixture strict validation -------------------------------------------------------------------

func test_fixture_counts_match_contract() -> void:
	"""The transcribed manifest fixture counts match the frozen contract's stated totals."""
	assert_equal(SINGLE_FAULT_CASES.size(), 40, "40 frozen manifest scalar cases")
	assert_equal(ROW_POSITIONS.size(), 5, "5 frozen row positions")
	assert_equal(FIELD_NAMES.size(), 16, "16 frozen fields")
	assert_equal(FIELD_NAMES.size() * SHAPE_LENGTHS.size(), 48, "48 frozen shape cases")
	assert_equal(FLAG_FIELDS.size(), 3, "3 frozen flag buffers")
	assert_equal(GATE_COLLISION_PAIRS.size(), 7, "7 ordered within-row gate collision pairs")


# --- null image ------------------------------------------------------------------------------

func test_null_image_refuses_shape() -> void:
	"""A null image reference is refused as COLUMN_SHAPE."""
	assert_equal(Construction.columns_refusal(null), StringName("COLUMN_SHAPE"), "null image")


# --- borrowed image: all 16 columns empty and correctly typed (F4) ------------------------------

static func _column_by_name(image: Construction.Columns, field: String) -> Variant:
	"""The typed packed column property named by one frozen field name, for inspection."""
	match field:
		"present": return image.present
		"material_container_slot": return image.material_container_slot
		"material_container_generation": return image.material_container_generation
		"assigned_count": return image.assigned_count
		"max_workers": return image.max_workers
		"refund_policy": return image.refund_policy
		"remaining_mwu": return image.remaining_mwu
		"paused": return image.paused
		"work_begun": return image.work_begun
		"ref_slot": return image.ref_slot
		"ref_generation": return image.ref_generation
		"subject_slot": return image.subject_slot
		"subject_generation": return image.subject_generation
		"purpose": return image.purpose
		"type_id": return image.type_id
		"phase": return image.phase
	return null


func test_borrowed_image_all_columns_empty_and_typed() -> void:
	"""Every one of the 16 typed columns of a borrowed image is empty and the declared type."""
	var image: Construction.Columns = Construction.Columns.new(false)
	for field: String in FIELD_NAMES:
		var column: Variant = _column_by_name(image, field)
		assert_equal(typeof(column), int(FIELD_TYPE_CODES[field]), "%s type" % field)
		assert_equal(column.size(), 0, "%s empty" % field)
	assert_false(image.is_sized(), "borrowed is not sized")


# --- default image: all 16 columns typed, sized and at their clear value (F4) -------------------

func test_default_image_is_sized_and_accepted() -> void:
	"""The default clear image is sized and accepted by the pure predicate."""
	var image: Construction.Columns = Construction.Columns.new(true)
	assert_true(image.is_sized(), "default image is sized")
	assert_equal(Construction.columns_refusal(image), StringName(""), "default clear accepted")


func test_default_image_all_types_extents_and_clear_values() -> void:
	"""Every one of the 16 typed columns has the declared type, OWNER_CAPACITY extent and clear
	value at row 0."""
	var image: Construction.Columns = Construction.Columns.new(true)
	for field: String in FIELD_NAMES:
		var column: Variant = _column_by_name(image, field)
		assert_equal(typeof(column), int(FIELD_TYPE_CODES[field]), "%s type" % field)
		assert_equal(column.size(), OWNER_CAPACITY, "%s extent" % field)
		assert_equal(column[0], BASE_CLEAR[field], "%s clear value" % field)


# --- 48 field shape faults -------------------------------------------------------------------

static func _shape_broken_image(field: String, length: int) -> Construction.Columns:
	"""A default image with exactly one named field resized to an off-contract length."""
	var image: Construction.Columns = Construction.Columns.new(true)
	match field:
		"present": image.present.resize(length)
		"material_container_slot": image.material_container_slot.resize(length)
		"material_container_generation": image.material_container_generation.resize(length)
		"assigned_count": image.assigned_count.resize(length)
		"max_workers": image.max_workers.resize(length)
		"refund_policy": image.refund_policy.resize(length)
		"remaining_mwu": image.remaining_mwu.resize(length)
		"paused": image.paused.resize(length)
		"work_begun": image.work_begun.resize(length)
		"ref_slot": image.ref_slot.resize(length)
		"ref_generation": image.ref_generation.resize(length)
		"subject_slot": image.subject_slot.resize(length)
		"subject_generation": image.subject_generation.resize(length)
		"purpose": image.purpose.resize(length)
		"type_id": image.type_id.resize(length)
		"phase": image.phase.resize(length)
	return image


func test_shape_cases() -> void:
	"""All 16 fields x [0, 82943, 82945] refuse as COLUMN_SHAPE (48 cases)."""
	for field: String in FIELD_NAMES:
		for length: int in SHAPE_LENGTHS:
			var image: Construction.Columns = _shape_broken_image(field, length)
			var code: StringName = Construction.columns_refusal(image)
			assert_equal(code, StringName("COLUMN_SHAPE"), "field %s length %d" % [field, length])


# --- row-value helpers -------------------------------------------------------------------------

static func _set_row(image: Construction.Columns, row: int, v: Dictionary) -> void:
	"""Write all 16 fields of one dictionary template into one row of an image."""
	image.present[row] = v["present"]
	image.material_container_slot[row] = v["material_container_slot"]
	image.material_container_generation[row] = v["material_container_generation"]
	image.assigned_count[row] = v["assigned_count"]
	image.max_workers[row] = v["max_workers"]
	image.refund_policy[row] = v["refund_policy"]
	image.remaining_mwu[row] = v["remaining_mwu"]
	image.paused[row] = v["paused"]
	image.work_begun[row] = v["work_begun"]
	image.ref_slot[row] = v["ref_slot"]
	image.ref_generation[row] = v["ref_generation"]
	image.subject_slot[row] = v["subject_slot"]
	image.subject_generation[row] = v["subject_generation"]
	image.purpose[row] = v["purpose"]
	image.type_id[row] = v["type_id"]
	image.phase[row] = v["phase"]


static func _merged(base: Dictionary, changes: Dictionary) -> Dictionary:
	"""A shallow copy of `base` with `changes` applied on top."""
	var out: Dictionary = base.duplicate()
	for key: String in changes.keys():
		out[key] = changes[key]
	return out


static func _base_by_name(name: String) -> Dictionary:
	"""One of the three frozen bases by its manifest name."""
	if name == "clear":
		return BASE_CLEAR
	if name == "live":
		return BASE_LIVE
	return BASE_RETIRED


static func _clear_image_with_row(row: int, values: Dictionary) -> Construction.Columns:
	"""A default clear image with exactly one row overwritten to `values`."""
	var image: Construction.Columns = Construction.Columns.new(true)
	_set_row(image, row, values)
	return image


# --- 40 manifest scalar cases at 5 physical row positions ---------------------------------------

func test_single_fault_cases() -> void:
	"""Every frozen single-fault case at every frozen row position."""
	for case: Dictionary in SINGLE_FAULT_CASES:
		for row: int in ROW_POSITIONS:
			_assert_single_fault(case, row)


func _assert_single_fault(case: Dictionary, row: int) -> void:
	"""One manifest case applied at one row, asserted against its frozen expected code."""
	var base: Dictionary = _base_by_name(case["base"])
	var values: Dictionary = _merged(base, case["changes"])
	var image: Construction.Columns = _clear_image_with_row(row, values)
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName(case["expected"]), "case %s row %d" % [case["id"], row])


# --- flag scan: 3 buffers x [2,255] at the frozen positions, plus precedence --------------------

func test_flag_scan_refuses() -> void:
	"""Every flag buffer x invalid value x frozen position refuses as COLUMN_FLAG."""
	for field: String in FLAG_FIELDS:
		for value: int in FLAG_INVALID_VALUES:
			for pos: int in FLAG_POSITIONS:
				_assert_flag_fault(field, value, pos)


func _assert_flag_fault(field: String, value: int, pos: int) -> void:
	"""One flag-buffer byte fault at one position, asserted as COLUMN_FLAG."""
	var image: Construction.Columns = Construction.Columns.new(true)
	match field:
		"present": image.present[pos] = value
		"paused": image.paused[pos] = value
		"work_begun": image.work_begun[pos] = value
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName("COLUMN_FLAG"), "%s=%d at %d" % [field, value, pos])


func test_flag_precedes_earlier_row_semantic_fault() -> void:
	"""The flag scan outruns a semantic fault on an earlier row than the flag violation."""
	var image: Construction.Columns = _clear_image_with_row(0, _merged(BASE_LIVE, {"purpose": 4}))
	image.paused[82943] = 2
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName("COLUMN_FLAG"), "flag scan precedes row 0's enum fault")


# --- row ordering: first failing row wins, ascending ---------------------------------------------

func test_row_scan_returns_first_failing_row_ascending() -> void:
	"""Row scan is ascending; the earlier failing row's code is returned."""
	var image: Construction.Columns = _clear_image_with_row(5, _merged(BASE_LIVE, {"purpose": 4}))
	_set_row(image, 6, _merged(BASE_LIVE, {"max_workers": 3}))
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName("COLUMN_ENUM"), "row 5 enum fault found before row 6's fault")


# --- ordered within-row gate collisions (F5) ------------------------------------------------------

func test_gate_collision_pairs() -> void:
	"""Each frozen (later-only baseline, earlier-plus-later combined) collision pair."""
	for case: Dictionary in GATE_COLLISION_PAIRS:
		_assert_gate_collision(case)


func _assert_gate_collision(case: Dictionary) -> void:
	"""Assert the later-only baseline first, then the earlier-wins combined result."""
	var base: Dictionary = _base_by_name(case["base"])
	var later_only: Dictionary = _merged(base, case["later"])
	var baseline_image: Construction.Columns = _clear_image_with_row(0, later_only)
	assert_equal(Construction.columns_refusal(baseline_image), StringName(case["later_expected"]),
		"%s baseline (later-only)" % case["id"])
	var combined: Dictionary = _merged(later_only, case["earlier"])
	var combined_image: Construction.Columns = _clear_image_with_row(0, combined)
	assert_equal(Construction.columns_refusal(combined_image), StringName(case["earlier_expected"]),
		"%s combined (earlier wins)" % case["id"])


# --- direct entry collision: shape precedes source metadata (source is currently coherent) ------

func test_shape_gate_precedes_source_metadata_gate() -> void:
	"""A shape-invalid image is refused as shape regardless of source coherence."""
	var image: Construction.Columns = _shape_broken_image("present", 0)
	assert_equal(Construction.columns_refusal(image), StringName("COLUMN_SHAPE"),
		"shape-invalid image is refused as shape")


func test_source_metadata_gate_currently_passes() -> void:
	"""Baseline only: the SOURCE_METADATA-vs-FLAG collision needs an injected source fault,
	deferred to a later fault-injection campaign per the contract's own boundary."""
	assert_equal(Construction.column_source_metadata_refusal(), StringName(""),
		"pure source preflight currently accepts the unmodified source")


# --- Directory / Inventory reference boundary successes ------------------------------------------

func test_directory_final_slot_boundary_accepted() -> void:
	"""Directory's final slot 352417 at max generation is a locally valid self reference."""
	var v: Dictionary = _merged(BASE_LIVE, {"ref_slot": 352417, "ref_generation": 2147483647})
	var image: Construction.Columns = _clear_image_with_row(0, v)
	assert_equal(Construction.columns_refusal(image), StringName(""), "final directory slot ok")


func test_inventory_container_full_i32_boundary_accepted() -> void:
	"""Inventory's full signed-i32 container namespace is a locally valid container reference."""
	var v: Dictionary = _merged(BASE_LIVE, {
		"material_container_slot": 2147483647, "material_container_generation": 2147483647})
	var image: Construction.Columns = _clear_image_with_row(0, v)
	assert_equal(Construction.columns_refusal(image), StringName(""), "container i32 max ok")


func test_structurally_stale_self_reference_accepted_locally() -> void:
	"""A structurally-shaped but Directory-unverified self reference is locally accepted."""
	var v: Dictionary = _merged(BASE_LIVE, {"ref_slot": 5, "ref_generation": 999})
	var image: Construction.Columns = _clear_image_with_row(0, v)
	assert_equal(Construction.columns_refusal(image), StringName(""),
		"structurally-shaped stale self reference is locally accepted")


# --- valid tuple matrix: every purpose/type/phase/work-boundary/worker-boundary/paused tuple ----

static func _declared_work(purpose: int, type_id: int) -> int:
	"""The independently frozen declared work W for one purpose/type pair."""
	if purpose == P_FURNITURE:
		return T_FURNITURE_WORK[type_id]
	if purpose == P_UPGRADE:
		return T_UPGRADE_WORK[T_UPGRADE_IDS.find(type_id)]
	if purpose == P_DEMOLISH:
		return T_BUILDING_WORK[type_id] * 1 / 4
	return T_BUILDING_WORK[type_id]


static func _bill_pairs(purpose: int, type_id: int) -> int:
	"""The independently frozen delivery-bill pair count for one purpose/type pair."""
	if purpose == P_FURNITURE:
		return T_FURNITURE_BILL_PAIRS[type_id]
	if purpose == P_UPGRADE:
		return T_UPGRADE_BILL_PAIRS[T_UPGRADE_IDS.find(type_id)]
	if purpose == P_DEMOLISH:
		return 0
	return T_BUILDING_BILL_PAIRS[type_id]


static func _worker_paused_pairs(phase: int) -> Array[Array]:
	"""Every admissible (paused, assigned) pair for a phase; paused/refunding forces assigned 0."""
	if phase == PH_REFUNDING:
		return [[0, 0], [1, 0]]
	return [[0, 0], [0, T_MAX_WORKERS], [1, 0]]


static func _valid_row(purpose: int, type_id: int, phase: int, work_begun: int,
		remaining: int, assigned: int, paused: int) -> Dictionary:
	"""One live (present1) row template, with refund_policy derived from purpose/work_begun."""
	var policy: int = R_DEMOLITION
	if purpose != P_DEMOLISH:
		policy = R_PARTIAL if work_begun == 1 else R_FULL
	return {
		"present": 1, "material_container_slot": -1, "material_container_generation": 0,
		"assigned_count": assigned, "max_workers": T_MAX_WORKERS, "refund_policy": policy,
		"remaining_mwu": remaining, "paused": paused, "work_begun": work_begun,
		"ref_slot": 0, "ref_generation": 1, "subject_slot": 1, "subject_generation": 1,
		"purpose": purpose, "type_id": type_id, "phase": phase,
	}


static func _rows_for(purpose: int, type_id: int, phase: int, begun: int,
		remaining: int) -> Array[Dictionary]:
	"""One (phase, work_begun, remaining) tuple expanded across every admissible worker/paused pair."""
	var out: Array[Dictionary] = []
	for pair: Array in _worker_paused_pairs(phase):
		out.append(_valid_row(purpose, type_id, phase, begun, remaining, pair[1], pair[0]))
	return out


static func _phase_variants(purpose: int, type_id: int) -> Array[Dictionary]:
	"""Every admissible live phase/work-boundary/worker/paused tuple for one purpose/type pair."""
	var w: int = _declared_work(purpose, type_id)
	var out: Array[Dictionary] = []
	if _bill_pairs(purpose, type_id) > 0:
		out.append_array(_rows_for(purpose, type_id, PH_AWAITING, 0, w))
	out.append_array(_rows_for(purpose, type_id, PH_READY, 0, w))
	out.append_array(_rows_for(purpose, type_id, PH_WORKING, 1, 1))
	out.append_array(_rows_for(purpose, type_id, PH_WORKING, 1, w))
	out.append_array(_rows_for(purpose, type_id, PH_WORK_DONE, 1, 0))
	out.append_array(_rows_for(purpose, type_id, PH_REFUNDING, 0, w))
	out.append_array(_rows_for(purpose, type_id, PH_REFUNDING, 1, 0))
	out.append_array(_rows_for(purpose, type_id, PH_REFUNDING, 1, 1))
	out.append_array(_rows_for(purpose, type_id, PH_REFUNDING, 1, w))
	return out


static func _retired_row(purpose: int, type_id: int, phase: int, policy: int) -> Dictionary:
	"""One retired (present0) row: null self/subject/container, zeroed mutable fields."""
	return {
		"present": 0, "material_container_slot": -1, "material_container_generation": 0,
		"assigned_count": 0, "max_workers": T_MAX_WORKERS, "refund_policy": policy,
		"remaining_mwu": 0, "paused": 0, "work_begun": 0, "ref_slot": -1, "ref_generation": 0,
		"subject_slot": -1, "subject_generation": 0, "purpose": purpose, "type_id": type_id,
		"phase": phase,
	}


static func _retired_variants(purpose: int, type_id: int) -> Array[Dictionary]:
	"""Every admissible retired row for one purpose/type pair: WORK_DONE and REFUNDING policies."""
	var out: Array[Dictionary] = []
	out.append(_retired_row(purpose, type_id, PH_WORK_DONE,
		R_DEMOLITION if purpose == P_DEMOLISH else R_PARTIAL))
	if purpose == P_DEMOLISH:
		out.append(_retired_row(purpose, type_id, PH_REFUNDING, R_DEMOLITION))
	else:
		out.append(_retired_row(purpose, type_id, PH_REFUNDING, R_FULL))
		out.append(_retired_row(purpose, type_id, PH_REFUNDING, R_PARTIAL))
	return out


static func _all_valid_rows() -> Array[Dictionary]:
	"""Every admissible live and retired tuple across all 73 types, plus one explicit clear row."""
	var out: Array[Dictionary] = [BASE_CLEAR.duplicate()]
	for id: int in 30:
		out.append_array(_phase_variants(P_BUILD, id))
		out.append_array(_retired_variants(P_BUILD, id))
		out.append_array(_phase_variants(P_DEMOLISH, id))
		out.append_array(_retired_variants(P_DEMOLISH, id))
	for id: int in 9:
		out.append_array(_phase_variants(P_FURNITURE, id))
		out.append_array(_retired_variants(P_FURNITURE, id))
	for id: int in T_UPGRADE_IDS:
		out.append_array(_phase_variants(P_UPGRADE, id))
		out.append_array(_retired_variants(P_UPGRADE, id))
	return out


static func _print_marker(rows: Array[Dictionary]) -> void:
	"""One compact JSON marker with the expanded positive tuple count and full tuple data."""
	var marker: Dictionary = {
		"suite": "test_construction_columns",
		"expanded_positive_tuple_count": rows.size(),
		"tuples": rows,
	}
	print(JSON.stringify(marker))


func test_packed_valid_tuples_image_accepted() -> void:
	"""Every generated valid tuple, packed sequentially into one image, is accepted."""
	var rows: Array[Dictionary] = _all_valid_rows()
	assert_true(rows.size() > 0 and rows.size() < OWNER_CAPACITY, "tuple count is bounded")
	var image: Construction.Columns = Construction.Columns.new(true)
	for i: int in rows.size():
		_set_row(image, i, rows[i])
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName(""), "packed valid tuples image accepted")
	_print_marker(rows)


func test_full_capacity_mixed_image_accepted() -> void:
	"""All 82944 rows, cycling through every generated valid tuple, are accepted."""
	var rows: Array[Dictionary] = _all_valid_rows()
	var image: Construction.Columns = Construction.Columns.new(true)
	for row: int in OWNER_CAPACITY:
		_set_row(image, row, rows[row % rows.size()])
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName(""), "full capacity mixed image accepted")


# --- independent negative phase-relation cases: work=60000 (type19), earlier gates valid --------

const NEGATIVE_PHASE_CASES: Array[Dictionary] = [
	{"id": "ready-begun1-remaining-w",
		"changes": {"phase": 1, "work_begun": 1, "refund_policy": 1}},
	{"id": "ready-begun0-remaining-w-minus-1", "changes": {"phase": 1, "remaining_mwu": 59999}},
	{"id": "working-begun0-remaining-1", "changes": {"phase": 2, "remaining_mwu": 1}},
	{"id": "working-begun1-remaining-w-plus-1",
		"changes": {"phase": 2, "work_begun": 1, "refund_policy": 1, "remaining_mwu": 60001}},
	{"id": "work-done-begun0-remaining-0", "changes": {"phase": 3, "remaining_mwu": 0}},
	{"id": "refund-begun1-remaining-w-plus-1", "changes": {"phase": 4, "work_begun": 1,
		"refund_policy": 1, "remaining_mwu": 60001, "assigned_count": 0}},
]


func test_negative_phase_case_count() -> void:
	"""The six frozen negative phase-relation cases are present; none are silently dropped."""
	assert_equal(NEGATIVE_PHASE_CASES.size(), 6, "6 frozen negative phase-relation cases")


func test_negative_phase_relation_cases() -> void:
	"""Each frozen negative phase-relation case, at every frozen row position, after first
	showing the unmodified BASE_LIVE control at that row is accepted."""
	for case: Dictionary in NEGATIVE_PHASE_CASES:
		for row: int in ROW_POSITIONS:
			_assert_negative_phase_case(case, row)


func _assert_negative_phase_case(case: Dictionary, row: int) -> void:
	"""Assert the BASE_LIVE control reaches NONE, then the case's earlier-valid PHASE fault."""
	var control_image: Construction.Columns = _clear_image_with_row(row, BASE_LIVE)
	assert_equal(Construction.columns_refusal(control_image), StringName(""),
		"%s row %d control (BASE_LIVE) accepted" % [case["id"], row])
	var faulted: Dictionary = _merged(BASE_LIVE, case["changes"])
	var image: Construction.Columns = _clear_image_with_row(row, faulted)
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName("COLUMN_PHASE"), "%s row %d" % [case["id"], row])
