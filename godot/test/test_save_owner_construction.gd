extends "res://test/framework/test_case.gd"
## Independent functional tests of the section 4 owner 1 bridge
## (save_owner_construction.gd, CONSTRUCTION-S4-VALIDATE-R01v2, ADR 0186), built against
## Section.FramedOwner's actual public API. Does not test a handwritten duplicate mapper: the
## projection assertions call the bridge's own static `_project_columns` directly.

const Section := preload("res://scripts/core/save_section_component_columns.gd")
const SOC := preload("res://scripts/core/save_owner_construction.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Construction := preload("res://scripts/core/construction.gd")

const CAP: int = 82944

const COLUMNS_PROPERTY_NAMES: Array[String] = [
	"present", "material_container_slot", "material_container_generation", "assigned_count",
	"max_workers", "refund_policy", "remaining_mwu", "paused", "work_begun", "ref_slot",
	"ref_generation", "subject_slot", "subject_generation", "purpose", "type_id", "phase",
]


static func _filled_i32(value: int) -> PackedInt32Array:
	"""An 82944-length i32 column filled with one value."""
	var a: PackedInt32Array = PackedInt32Array()
	a.resize(CAP)
	a.fill(value)
	return a


static func _filled_i64(value: int) -> PackedInt64Array:
	"""An 82944-length i64 column filled with one value."""
	var a: PackedInt64Array = PackedInt64Array()
	a.resize(CAP)
	a.fill(value)
	return a


static func _filled_u8(value: int) -> PackedByteArray:
	"""An 82944-length u8 column filled with one value."""
	var a: PackedByteArray = PackedByteArray()
	a.resize(CAP)
	a.fill(value)
	return a


static func _build_valid_record() -> Section.FramedOwner:
	"""A shape-valid, semantically-valid (all rows clear) owner 1 record, via the real API."""
	var record: Section.FramedOwner = Section.FramedOwner.new(SOC.OWNER_INDEX)
	record.set_u8(SOC.FIELD_PRESENT, _filled_u8(0))
	record.set_i32(SOC.FIELD_MATERIAL_CONTAINER_SLOT, _filled_i32(-1))
	record.set_i32(SOC.FIELD_MATERIAL_CONTAINER_GENERATION, _filled_i32(0))
	record.set_i32(SOC.FIELD_ASSIGNED_COUNT, _filled_i32(0))
	record.set_i32(SOC.FIELD_MAX_WORKERS, _filled_i32(0))
	record.set_i32(SOC.FIELD_REFUND_POLICY, _filled_i32(0))
	record.set_i64(SOC.FIELD_REMAINING_MWU, _filled_i64(0))
	record.set_u8(SOC.FIELD_PAUSED, _filled_u8(0))
	record.set_u8(SOC.FIELD_WORK_BEGUN, _filled_u8(0))
	record.set_i32(SOC.FIELD_REF_SLOT, _filled_i32(-1))
	record.set_i32(SOC.FIELD_REF_GENERATION, _filled_i32(0))
	record.set_i32(SOC.FIELD_SUBJECT_SLOT, _filled_i32(-1))
	record.set_i32(SOC.FIELD_SUBJECT_GENERATION, _filled_i32(0))
	record.set_i32(SOC.FIELD_PURPOSE, _filled_i32(0))
	record.set_i32(SOC.FIELD_TYPE_ID, _filled_i32(-1))
	record.set_i32(SOC.FIELD_PHASE, _filled_i32(0))
	return record


static func _set_row_field_i32(record: Section.FramedOwner, row: int, field: int,
		value: int) -> void:
	"""Mutate one row of an i32 field through the record's real set_i32 setter."""
	var column: PackedInt32Array = record.i32_column(field)
	column[row] = value
	record.set_i32(field, column)


static func _set_row_field_u8(record: Section.FramedOwner, row: int, field: int,
		value: int) -> void:
	"""Mutate one row of a u8 field through the record's real set_u8 setter."""
	var column: PackedByteArray = record.u8_column(field)
	column[row] = value
	record.set_u8(field, column)


static func _set_row_field_i64(record: Section.FramedOwner, row: int, field: int,
		value: int) -> void:
	"""Mutate one row of an i64 field through the record's real set_i64 setter."""
	var column: PackedInt64Array = record.i64_column(field)
	column[row] = value
	record.set_i64(field, column)


static func _apply_live_row(record: Section.FramedOwner, row: int, overrides: Dictionary) -> void:
	"""Set one row to independently frozen live-project values via the record's real typed
	setters, with optional field overrides (e.g. a deliberately wrong max_workers)."""
	_set_row_field_u8(record, row, SOC.FIELD_PRESENT, 1)
	_set_row_field_i32(record, row, SOC.FIELD_MATERIAL_CONTAINER_SLOT, -1)
	_set_row_field_i32(record, row, SOC.FIELD_MATERIAL_CONTAINER_GENERATION, 0)
	_set_row_field_i32(record, row, SOC.FIELD_ASSIGNED_COUNT, 0)
	_set_row_field_i32(record, row, SOC.FIELD_MAX_WORKERS, int(overrides.get("max_workers", 4)))
	_set_row_field_i32(record, row, SOC.FIELD_REFUND_POLICY, 0)
	_set_row_field_i64(record, row, SOC.FIELD_REMAINING_MWU, 60000)
	_set_row_field_u8(record, row, SOC.FIELD_PAUSED, 0)
	_set_row_field_u8(record, row, SOC.FIELD_WORK_BEGUN, 0)
	_set_row_field_i32(record, row, SOC.FIELD_REF_SLOT, 0)
	_set_row_field_i32(record, row, SOC.FIELD_REF_GENERATION, 1)
	_set_row_field_i32(record, row, SOC.FIELD_SUBJECT_SLOT, 1)
	_set_row_field_i32(record, row, SOC.FIELD_SUBJECT_GENERATION, 1)
	_set_row_field_i32(record, row, SOC.FIELD_PURPOSE, 0)
	_set_row_field_i32(record, row, SOC.FIELD_TYPE_ID, 19)
	_set_row_field_i32(record, row, SOC.FIELD_PHASE, 0)


# --- gate order: null, wrong owner, valid accepted --------------------------------------------

func test_null_record_refuses_shape() -> void:
	"""A null record is refused as the section's own SAVE_COMPONENT_SHAPE."""
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(null)
	assert_equal(refusal.code, Section.REFUSE_SHAPE, "null record refuses shape")


func test_wrong_owner_index_refuses_owner() -> void:
	"""A correctly-shaped owner-0 record is refused as SAVE_COMPONENT_OWNER before any other gate."""
	var record: Section.FramedOwner = Section.FramedOwner.new(0)
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(record)
	assert_equal(refusal.code, Section.REFUSE_OWNER, "owner 0 refuses the owner gate")


func test_valid_clear_record_accepted_with_empty_detail() -> void:
	"""A valid all-clear record is accepted with an empty code and detail."""
	var record: Section.FramedOwner = _build_valid_record()
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(record)
	assert_equal(refusal.code, SaveHeader.REFUSE_NONE, "valid clear record accepted")
	assert_equal(refusal.detail, "", "success has empty detail")


# --- ordinary framed shape faults, via the record's own public bucket properties ----------------

func test_corrupted_u8_column_extent_refuses_shape() -> void:
	"""A u8 column whose extent is directly broken is refused as the section's own shape code."""
	var record: Section.FramedOwner = _build_valid_record()
	var index: int = Schema.storage_index(SOC.OWNER_INDEX, SOC.FIELD_PRESENT)
	record.u8_columns[index] = PackedByteArray()
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(record)
	assert_equal(refusal.code, Section.REFUSE_SHAPE, "corrupted u8 extent refuses shape")


func test_corrupted_i32_column_extent_refuses_shape() -> void:
	"""An i32 column whose extent is directly broken is refused as the section's own shape code."""
	var record: Section.FramedOwner = _build_valid_record()
	var index: int = Schema.storage_index(SOC.OWNER_INDEX, SOC.FIELD_PURPOSE)
	var wrong: PackedInt32Array = PackedInt32Array()
	wrong.resize(100)
	record.i32_columns[index] = wrong
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(record)
	assert_equal(refusal.code, Section.REFUSE_SHAPE, "corrupted i32 extent refuses shape")


func test_missing_bucket_column_refuses_shape() -> void:
	"""A directly removed bucket column is refused as the section's own shape code."""
	var record: Section.FramedOwner = _build_valid_record()
	record.u8_columns.remove_at(0)
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(record)
	assert_equal(refusal.code, Section.REFUSE_SHAPE, "missing bucket column refuses shape")


# --- pure-code forwarding with the exact gate-7 detail prefix ------------------------------------

func test_row_semantic_fault_forwards_exact_column_code() -> void:
	"""An invalid purpose at row 0 forwards the exact unwrapped COLUMN_ENUM code and gate-7 prefix."""
	var record: Section.FramedOwner = _build_valid_record()
	_set_row_field_i32(record, 0, SOC.FIELD_PURPOSE, 4)
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(record)
	assert_equal(refusal.code, StringName("COLUMN_ENUM"), "column code forwarded exactly")
	assert_true(refusal.detail.begins_with("Construction owner 1 "), "gate 7 detail prefix")


func test_row_workers_fault_forwards_exact_column_code() -> void:
	"""A live row valid except max_workers forwards COLUMN_WORKERS with the gate-7 prefix (F1)."""
	var record: Section.FramedOwner = _build_valid_record()
	_apply_live_row(record, 0, {"max_workers": 3})
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(record)
	assert_equal(refusal.code, StringName("COLUMN_WORKERS"), "wrong max_workers forwards exactly")
	assert_true(refusal.detail.begins_with("Construction owner 1 "), "gate 7 detail prefix")


# --- direct call to the bridge's own static projection helper (F6) ------------------------------

static func _pattern_record() -> Section.FramedOwner:
	"""A record whose 16 fields each carry a mutually distinguishable pattern value."""
	var record: Section.FramedOwner = Section.FramedOwner.new(SOC.OWNER_INDEX)
	record.set_u8(SOC.FIELD_PRESENT, _filled_u8(7))
	record.set_i32(SOC.FIELD_MATERIAL_CONTAINER_SLOT, _filled_i32(101))
	record.set_i32(SOC.FIELD_MATERIAL_CONTAINER_GENERATION, _filled_i32(102))
	record.set_i32(SOC.FIELD_ASSIGNED_COUNT, _filled_i32(103))
	record.set_i32(SOC.FIELD_MAX_WORKERS, _filled_i32(104))
	record.set_i32(SOC.FIELD_REFUND_POLICY, _filled_i32(105))
	record.set_i64(SOC.FIELD_REMAINING_MWU, _filled_i64(999999999999))
	record.set_u8(SOC.FIELD_PAUSED, _filled_u8(8))
	record.set_u8(SOC.FIELD_WORK_BEGUN, _filled_u8(9))
	record.set_i32(SOC.FIELD_REF_SLOT, _filled_i32(106))
	record.set_i32(SOC.FIELD_REF_GENERATION, _filled_i32(107))
	record.set_i32(SOC.FIELD_SUBJECT_SLOT, _filled_i32(108))
	record.set_i32(SOC.FIELD_SUBJECT_GENERATION, _filled_i32(109))
	record.set_i32(SOC.FIELD_PURPOSE, _filled_i32(110))
	record.set_i32(SOC.FIELD_TYPE_ID, _filled_i32(111))
	record.set_i32(SOC.FIELD_PHASE, _filled_i32(112))
	return record


func test_direct_project_columns_matches_distinguishable_patterns() -> void:
	"""Actual `_project_columns` output equals the record's own typed columns, in full, for all
	16 fields -- not merely their first elements -- with a shape guard before comparison."""
	var record: Section.FramedOwner = _pattern_record()
	var columns: Construction.Columns = Construction.Columns.new(false)
	SOC._project_columns(record, columns)
	assert_equal(columns.present.size(), CAP, "present column sized before comparison")
	assert_equal(columns.present, record.u8_column(SOC.FIELD_PRESENT), "present full column")
	assert_equal(columns.material_container_slot,
		record.i32_column(SOC.FIELD_MATERIAL_CONTAINER_SLOT), "container slot full column")
	assert_equal(columns.material_container_generation,
		record.i32_column(SOC.FIELD_MATERIAL_CONTAINER_GENERATION), "container gen full column")
	assert_equal(columns.assigned_count, record.i32_column(SOC.FIELD_ASSIGNED_COUNT),
		"assigned full column")
	assert_equal(columns.max_workers, record.i32_column(SOC.FIELD_MAX_WORKERS),
		"max workers full column")
	assert_equal(columns.refund_policy, record.i32_column(SOC.FIELD_REFUND_POLICY),
		"refund policy full column")
	assert_equal(columns.remaining_mwu, record.i64_column(SOC.FIELD_REMAINING_MWU),
		"remaining full column")
	assert_equal(columns.paused, record.u8_column(SOC.FIELD_PAUSED), "paused full column")
	assert_equal(columns.work_begun, record.u8_column(SOC.FIELD_WORK_BEGUN), "work begun full column")
	assert_equal(columns.ref_slot, record.i32_column(SOC.FIELD_REF_SLOT), "ref slot full column")
	assert_equal(columns.ref_generation, record.i32_column(SOC.FIELD_REF_GENERATION),
		"ref gen full column")
	assert_equal(columns.subject_slot, record.i32_column(SOC.FIELD_SUBJECT_SLOT),
		"subject slot full column, distinct from ref slot")
	assert_equal(columns.subject_generation, record.i32_column(SOC.FIELD_SUBJECT_GENERATION),
		"subject gen full column, distinct from ref gen")
	assert_equal(columns.purpose, record.i32_column(SOC.FIELD_PURPOSE), "purpose full column")
	assert_equal(columns.type_id, record.i32_column(SOC.FIELD_TYPE_ID), "type id full column")
	assert_equal(columns.phase, record.i32_column(SOC.FIELD_PHASE), "phase full column")


# --- all 16 fields individually omitted from a projected view are shape-invalid -----------------
# This is a SHAPE-only witness over a caller-assembled view (an omitted assignment leaves an
# empty typed array), not an injected source/catalog fault; that campaign is separate and later.

static func _project_all_except(record: Section.FramedOwner, out: Construction.Columns,
		omit: String) -> void:
	"""Assign 15 of the 16 typed columns from `record` into `out`, leaving `omit` unassigned."""
	if omit != "present": out.present = record.u8_column(SOC.FIELD_PRESENT)
	if omit != "material_container_slot":
		out.material_container_slot = record.i32_column(SOC.FIELD_MATERIAL_CONTAINER_SLOT)
	if omit != "material_container_generation":
		out.material_container_generation = \
			record.i32_column(SOC.FIELD_MATERIAL_CONTAINER_GENERATION)
	if omit != "assigned_count": out.assigned_count = record.i32_column(SOC.FIELD_ASSIGNED_COUNT)
	if omit != "max_workers": out.max_workers = record.i32_column(SOC.FIELD_MAX_WORKERS)
	if omit != "refund_policy": out.refund_policy = record.i32_column(SOC.FIELD_REFUND_POLICY)
	if omit != "remaining_mwu": out.remaining_mwu = record.i64_column(SOC.FIELD_REMAINING_MWU)
	if omit != "paused": out.paused = record.u8_column(SOC.FIELD_PAUSED)
	if omit != "work_begun": out.work_begun = record.u8_column(SOC.FIELD_WORK_BEGUN)
	if omit != "ref_slot": out.ref_slot = record.i32_column(SOC.FIELD_REF_SLOT)
	if omit != "ref_generation": out.ref_generation = record.i32_column(SOC.FIELD_REF_GENERATION)
	if omit != "subject_slot": out.subject_slot = record.i32_column(SOC.FIELD_SUBJECT_SLOT)
	if omit != "subject_generation":
		out.subject_generation = record.i32_column(SOC.FIELD_SUBJECT_GENERATION)
	if omit != "purpose": out.purpose = record.i32_column(SOC.FIELD_PURPOSE)
	if omit != "type_id": out.type_id = record.i32_column(SOC.FIELD_TYPE_ID)
	if omit != "phase": out.phase = record.i32_column(SOC.FIELD_PHASE)


func test_omitted_projection_assignment_is_shape_invalid() -> void:
	"""Each of the 16 fields, individually omitted from a projected view, yields COLUMN_SHAPE."""
	for field_name: String in COLUMNS_PROPERTY_NAMES:
		_assert_omitted_assignment_shape_invalid(field_name)


func _assert_omitted_assignment_shape_invalid(omit_field: String) -> void:
	"""One field omitted from an otherwise-complete projection is refused as COLUMN_SHAPE."""
	var record: Section.FramedOwner = _build_valid_record()
	var columns: Construction.Columns = Construction.Columns.new(false)
	_project_all_except(record, columns, omit_field)
	var code: StringName = Construction.columns_refusal(columns)
	assert_equal(code, StringName("COLUMN_SHAPE"), "omitting %s leaves columns unsized" % omit_field)


# --- nonmutation: direct caller-owned Columns, full 16-column before/after equality (F2) --------

static func _snapshot_columns(image: Construction.Columns) -> Dictionary:
	"""An independent deep-copy snapshot of all 16 typed columns of a Columns image."""
	return {
		"present": image.present.duplicate(), "material_container_slot":
			image.material_container_slot.duplicate(), "material_container_generation":
			image.material_container_generation.duplicate(),
		"assigned_count": image.assigned_count.duplicate(),
		"max_workers": image.max_workers.duplicate(),
		"refund_policy": image.refund_policy.duplicate(),
		"remaining_mwu": image.remaining_mwu.duplicate(), "paused": image.paused.duplicate(),
		"work_begun": image.work_begun.duplicate(), "ref_slot": image.ref_slot.duplicate(),
		"ref_generation": image.ref_generation.duplicate(),
		"subject_slot": image.subject_slot.duplicate(),
		"subject_generation": image.subject_generation.duplicate(),
		"purpose": image.purpose.duplicate(), "type_id": image.type_id.duplicate(),
		"phase": image.phase.duplicate(),
	}


func _assert_columns_match_snapshot(image: Construction.Columns, snap: Dictionary,
		label: String) -> void:
	"""Compare every one of an image's 16 typed columns against an independent snapshot."""
	assert_equal(image.present, snap["present"], "%s present" % label)
	assert_equal(image.material_container_slot, snap["material_container_slot"],
		"%s container slot" % label)
	assert_equal(image.material_container_generation, snap["material_container_generation"],
		"%s container gen" % label)
	assert_equal(image.assigned_count, snap["assigned_count"], "%s assigned" % label)
	assert_equal(image.max_workers, snap["max_workers"], "%s max workers" % label)
	assert_equal(image.refund_policy, snap["refund_policy"], "%s refund policy" % label)
	assert_equal(image.remaining_mwu, snap["remaining_mwu"], "%s remaining" % label)
	assert_equal(image.paused, snap["paused"], "%s paused" % label)
	assert_equal(image.work_begun, snap["work_begun"], "%s work begun" % label)
	assert_equal(image.ref_slot, snap["ref_slot"], "%s ref slot" % label)
	assert_equal(image.ref_generation, snap["ref_generation"], "%s ref gen" % label)
	assert_equal(image.subject_slot, snap["subject_slot"], "%s subject slot" % label)
	assert_equal(image.subject_generation, snap["subject_generation"], "%s subject gen" % label)
	assert_equal(image.purpose, snap["purpose"], "%s purpose" % label)
	assert_equal(image.type_id, snap["type_id"], "%s type id" % label)
	assert_equal(image.phase, snap["phase"], "%s phase" % label)


func test_direct_columns_full_equality_after_success() -> void:
	"""All 16 typed columns of a caller-owned image are unchanged after an accepted call."""
	var image: Construction.Columns = Construction.Columns.new(true)
	var snap: Dictionary = _snapshot_columns(image)
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName(""), "clear image accepted")
	_assert_columns_match_snapshot(image, snap, "success")


func test_direct_columns_full_equality_after_shape_refusal() -> void:
	"""All 16 typed columns are unchanged after a COLUMN_SHAPE refusal on a borrowed image."""
	var image: Construction.Columns = Construction.Columns.new(false)
	var snap: Dictionary = _snapshot_columns(image)
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName("COLUMN_SHAPE"), "borrowed refuses shape")
	_assert_columns_match_snapshot(image, snap, "shape refusal")


func test_direct_columns_full_equality_after_flag_refusal() -> void:
	"""All 16 typed columns are unchanged after a COLUMN_FLAG refusal."""
	var image: Construction.Columns = Construction.Columns.new(true)
	image.paused[0] = 2
	var snap: Dictionary = _snapshot_columns(image)
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName("COLUMN_FLAG"), "flag scan refuses")
	_assert_columns_match_snapshot(image, snap, "flag refusal")


func test_direct_columns_full_equality_after_late_semantic_refusal() -> void:
	"""All 16 typed columns are unchanged after a late-row (82943) COLUMN_ENUM refusal."""
	var image: Construction.Columns = Construction.Columns.new(true)
	image.purpose[82943] = 4
	var snap: Dictionary = _snapshot_columns(image)
	var code: StringName = Construction.columns_refusal(image)
	assert_equal(code, StringName("COLUMN_ENUM"), "late row 82943 enum fault found")
	_assert_columns_match_snapshot(image, snap, "late semantic refusal")


# --- nonmutation: framed record, full 16-column before/after equality (F2) ----------------------

static func _snapshot_record(record: Section.FramedOwner) -> Dictionary:
	"""An independent deep-copy snapshot of all 16 typed field columns of a framed record."""
	return {
		"present": record.u8_column(SOC.FIELD_PRESENT).duplicate(),
		"material_container_slot":
			record.i32_column(SOC.FIELD_MATERIAL_CONTAINER_SLOT).duplicate(),
		"material_container_generation":
			record.i32_column(SOC.FIELD_MATERIAL_CONTAINER_GENERATION).duplicate(),
		"assigned_count": record.i32_column(SOC.FIELD_ASSIGNED_COUNT).duplicate(),
		"max_workers": record.i32_column(SOC.FIELD_MAX_WORKERS).duplicate(),
		"refund_policy": record.i32_column(SOC.FIELD_REFUND_POLICY).duplicate(),
		"remaining_mwu": record.i64_column(SOC.FIELD_REMAINING_MWU).duplicate(),
		"paused": record.u8_column(SOC.FIELD_PAUSED).duplicate(),
		"work_begun": record.u8_column(SOC.FIELD_WORK_BEGUN).duplicate(),
		"ref_slot": record.i32_column(SOC.FIELD_REF_SLOT).duplicate(),
		"ref_generation": record.i32_column(SOC.FIELD_REF_GENERATION).duplicate(),
		"subject_slot": record.i32_column(SOC.FIELD_SUBJECT_SLOT).duplicate(),
		"subject_generation": record.i32_column(SOC.FIELD_SUBJECT_GENERATION).duplicate(),
		"purpose": record.i32_column(SOC.FIELD_PURPOSE).duplicate(),
		"type_id": record.i32_column(SOC.FIELD_TYPE_ID).duplicate(),
		"phase": record.i32_column(SOC.FIELD_PHASE).duplicate(),
	}


func _assert_record_matches_snapshot(record: Section.FramedOwner, snap: Dictionary,
		label: String) -> void:
	"""Compare every one of a framed record's 16 typed field columns against a snapshot."""
	assert_equal(record.u8_column(SOC.FIELD_PRESENT), snap["present"], "%s present" % label)
	assert_equal(record.i32_column(SOC.FIELD_MATERIAL_CONTAINER_SLOT),
		snap["material_container_slot"], "%s container slot" % label)
	assert_equal(record.i32_column(SOC.FIELD_MATERIAL_CONTAINER_GENERATION),
		snap["material_container_generation"], "%s container gen" % label)
	assert_equal(record.i32_column(SOC.FIELD_ASSIGNED_COUNT), snap["assigned_count"],
		"%s assigned" % label)
	assert_equal(record.i32_column(SOC.FIELD_MAX_WORKERS), snap["max_workers"],
		"%s max workers" % label)
	assert_equal(record.i32_column(SOC.FIELD_REFUND_POLICY), snap["refund_policy"],
		"%s refund policy" % label)
	assert_equal(record.i64_column(SOC.FIELD_REMAINING_MWU), snap["remaining_mwu"],
		"%s remaining" % label)
	assert_equal(record.u8_column(SOC.FIELD_PAUSED), snap["paused"], "%s paused" % label)
	assert_equal(record.u8_column(SOC.FIELD_WORK_BEGUN), snap["work_begun"], "%s work begun" % label)
	assert_equal(record.i32_column(SOC.FIELD_REF_SLOT), snap["ref_slot"], "%s ref slot" % label)
	assert_equal(record.i32_column(SOC.FIELD_REF_GENERATION), snap["ref_generation"],
		"%s ref gen" % label)
	assert_equal(record.i32_column(SOC.FIELD_SUBJECT_SLOT), snap["subject_slot"],
		"%s subject slot" % label)
	assert_equal(record.i32_column(SOC.FIELD_SUBJECT_GENERATION), snap["subject_generation"],
		"%s subject gen" % label)
	assert_equal(record.i32_column(SOC.FIELD_PURPOSE), snap["purpose"], "%s purpose" % label)
	assert_equal(record.i32_column(SOC.FIELD_TYPE_ID), snap["type_id"], "%s type id" % label)
	assert_equal(record.i32_column(SOC.FIELD_PHASE), snap["phase"], "%s phase" % label)


func test_framed_record_full_equality_after_success() -> void:
	"""All 16 typed field columns of a framed record are unchanged after an accepted call."""
	var record: Section.FramedOwner = _build_valid_record()
	var snap: Dictionary = _snapshot_record(record)
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(record)
	assert_equal(refusal.code, SaveHeader.REFUSE_NONE, "valid record accepted")
	_assert_record_matches_snapshot(record, snap, "success")


func test_framed_record_full_equality_after_representative_refusal() -> void:
	"""All 16 typed field columns of a framed record are unchanged after a forwarded refusal.
	Godot copy-on-write means this alone cannot prove direct-Columns nonmutation; the direct
	Columns witnesses above cover that separately."""
	var record: Section.FramedOwner = _build_valid_record()
	_set_row_field_i32(record, 0, SOC.FIELD_PURPOSE, 4)
	var snap: Dictionary = _snapshot_record(record)
	var refusal: SaveHeader.Refusal = SOC.framed_refusal(record)
	assert_equal(refusal.code, StringName("COLUMN_ENUM"), "refused with forwarded column code")
	_assert_record_matches_snapshot(record, snap, "representative refusal")
