extends "res://test/framework/test_case.gd"
## Diagnostic probe: can Construction.state_bytes() be safely observed at the current engine
## without hardcoded Variant-encoding headers/offsets, and does a retired project row retain
## the exact residual values REQ-SET-124-127's lifecycle predicts?
##
## THE SERIALIZATION-ORDER TABLE BELOW IS DECLARED INDEPENDENTLY, matching construction.gd's own
## `state_bytes()` append order verbatim (material_container_slot .. live_count), which is NOT
## §4.1's ordinal order. Each segment's expected byte length is measured at runtime from
## `var_to_bytes()` of a zeroed prototype of the exact same packed type and extent -- never an
## assumed 8-byte header or alignment constant -- so this decoder tracks whatever encoding the
## running engine actually produces. The total observed buffer length is checked against the sum
## of those measured lengths BEFORE any slicing; a mismatch refuses -- by the named
## TOTAL_LENGTH_MISMATCH code -- before any slice, decode or index is attempted.
##
## THE DECODER IS ROW-SCOPED. `_decode_row(bytes, row)` returns only that one row's 16 scalar
## fields, its 4 delivered-material cells and the store-wide live_count; it never retains all 18
## decoded segment buffers at once. Each segment is sliced, type/count-validated, its needed
## scalar(s) pulled out, and then the decoded array is dropped -- it is a loop-local variable
## reassigned on the next iteration, never stored beyond `_extract_scalar()`'s one call.
##
## THIS IS AN ENGINE-BOUND DIAGNOSTIC, NOT A SAVE FORMAT. No offset constant is asserted, no new
## persisted schema is proposed, and no production accessor is added; every value read here comes
## from the module's own public `state_bytes()`, its own public row-identity return values, and
## its own public PURPOSE/PHASE/REFUND/MAX_BUILDERS constants.

const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const START_MASK: int = 1
const DIRT_PATH_TILE: int = 10 * 128 + 10
const STOCKPILE_TILE_A: int = 20 * 128 + 20
const STOCKPILE_TILE_B: int = 30 * 128 + 30

## Frozen source facts (catalog.gd's compiled BUILDING_DEFINITION ids), asserted against the
## live catalog in each test rather than trusted from it, per the compiled-domain drift risk.
const DIRT_PATH_TYPE_ID: int = 6
const OPEN_STOCKPILE_TYPE_ID: int = 19

const CONSTRUCTION_CAPACITY: int = 82944
const DELIVERED_CELLS: int = 331776
const KIND_I32: String = "i32"
const KIND_I64: String = "i64"
const KIND_BYTE: String = "byte"

## The declared serialization order, verbatim from construction.gd's `state_bytes()` body.
const SEGMENT_NAMES: Array[String] = [
	"material_container_slot", "material_container_generation", "assigned_count",
	"max_workers", "refund_policy", "remaining_mwu", "paused", "present", "work_begun",
	"ref_slot", "ref_generation", "subject_slot", "subject_generation", "purpose",
	"type_id", "phase", "delivered_milli", "live_count",
]
const SEGMENT_KIND: Dictionary = {
	"material_container_slot": KIND_I32, "material_container_generation": KIND_I32,
	"assigned_count": KIND_I32, "max_workers": KIND_I32, "refund_policy": KIND_I32,
	"remaining_mwu": KIND_I64, "paused": KIND_BYTE, "present": KIND_BYTE,
	"work_begun": KIND_BYTE, "ref_slot": KIND_I32, "ref_generation": KIND_I32,
	"subject_slot": KIND_I32, "subject_generation": KIND_I32, "purpose": KIND_I32,
	"type_id": KIND_I32, "phase": KIND_I32, "delivered_milli": KIND_I64, "live_count": KIND_I64,
}
const SEGMENT_EXTENT: Dictionary = {
	"material_container_slot": CONSTRUCTION_CAPACITY,
	"material_container_generation": CONSTRUCTION_CAPACITY,
	"assigned_count": CONSTRUCTION_CAPACITY, "max_workers": CONSTRUCTION_CAPACITY,
	"refund_policy": CONSTRUCTION_CAPACITY, "remaining_mwu": CONSTRUCTION_CAPACITY,
	"paused": CONSTRUCTION_CAPACITY, "present": CONSTRUCTION_CAPACITY,
	"work_begun": CONSTRUCTION_CAPACITY, "ref_slot": CONSTRUCTION_CAPACITY,
	"ref_generation": CONSTRUCTION_CAPACITY, "subject_slot": CONSTRUCTION_CAPACITY,
	"subject_generation": CONSTRUCTION_CAPACITY, "purpose": CONSTRUCTION_CAPACITY,
	"type_id": CONSTRUCTION_CAPACITY, "phase": CONSTRUCTION_CAPACITY,
	"delivered_milli": DELIVERED_CELLS, "live_count": 1,
}

var _buildings: Buildings = null
var _construction: Construction = null
var _out: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Build a private Construction store over its own fresh Building store."""
	_buildings = Buildings.new()
	_construction = Construction.new(_buildings)
	_out = IntMath.IntResult.new()


func after_each() -> void:
	"""Drop the fixture so no test inherits another's rows."""
	_construction = null
	_buildings = null


func _require(ok: bool, message: String) -> bool:
	"""Assert `ok` and return it, so a failed setup step can end its test method safely."""
	assert_true(ok, message)
	return ok


# --- the length-derived, row-scoped decoder -------------------------------------------------

func _zeroed(kind: String, extent: int) -> Variant:
	"""A zero-filled packed array of the given kind and extent, for length measurement only."""
	match kind:
		KIND_I32:
			var a32: PackedInt32Array = PackedInt32Array()
			a32.resize(extent)
			return a32
		KIND_I64:
			var a64: PackedInt64Array = PackedInt64Array()
			a64.resize(extent)
			return a64
		_:
			var ab: PackedByteArray = PackedByteArray()
			ab.resize(extent)
			return ab


func _expected_variant_type(kind: String) -> int:
	"""The Variant type bytes_to_var() must produce for one segment kind."""
	match kind:
		KIND_I32:
			return TYPE_PACKED_INT32_ARRAY
		KIND_I64:
			return TYPE_PACKED_INT64_ARRAY
		_:
			return TYPE_PACKED_BYTE_ARRAY


func _measure_segment_lengths() -> PackedInt64Array:
	"""The var_to_bytes() length of a zeroed prototype for each segment, in declared order."""
	var lengths: PackedInt64Array = PackedInt64Array()
	for name: String in SEGMENT_NAMES:
		var kind: String = String(SEGMENT_KIND[name])
		var extent: int = int(SEGMENT_EXTENT[name])
		var prototype: Variant = _zeroed(kind, extent)
		lengths.append(var_to_bytes(prototype).size())
	return lengths


func _extract_scalar(result: Dictionary, name: String, decoded: Variant, row: int) -> void:
	"""Pull this segment's needed scalar(s) for `row` into `result`.

	`decoded` is the caller's loop-local variable; nothing here stores a reference to it beyond
	this call, so the full segment buffer is eligible for collection the moment the loop moves on.
	"""
	if name == "delivered_milli":
		var cells: Array = []
		for index: int in 4:
			cells.append(int(decoded[row * 4 + index]))
		result["delivered"] = cells
	elif name == "live_count":
		result["live_count"] = int(decoded[0])
	else:
		result[name] = int(decoded[row])


func _decode_row(bytes: PackedByteArray, row: int) -> Dictionary:
	"""Decode exactly one project row's scalars from a Construction.state_bytes() image.

	Refuses -- before any slice, decode or index -- when `row` is out of range or the total
	observed length disagrees with the sum of the independently measured per-segment lengths.
	Each segment is then type- and count-checked before its scalar(s) are extracted; only the
	extracted row values are returned, never all 18 decoded buffers.
	"""
	if row < 0 or row >= CONSTRUCTION_CAPACITY:
		return {"ok": false, "error": "ROW_OUT_OF_RANGE"}
	var lengths: PackedInt64Array = _measure_segment_lengths()
	var total: int = 0
	for length: int in lengths:
		total += length
	if bytes.size() != total:
		return {"ok": false, "error": "TOTAL_LENGTH_MISMATCH"}
	var result: Dictionary = {"ok": true, "error": ""}
	var offset: int = 0
	for index: int in SEGMENT_NAMES.size():
		var name: String = SEGMENT_NAMES[index]
		var length: int = lengths[index]
		var piece: PackedByteArray = bytes.slice(offset, offset + length)
		var decoded: Variant = bytes_to_var(piece)
		var extent: int = int(SEGMENT_EXTENT[name])
		var expected_type: int = _expected_variant_type(String(SEGMENT_KIND[name]))
		if typeof(decoded) != expected_type:
			return {"ok": false, "error": "TYPE_MISMATCH:%s" % name}
		if int(decoded.size()) != extent:
			return {"ok": false, "error": "COUNT_MISMATCH:%s" % name}
		_extract_scalar(result, name, decoded, row)
		offset += length
	return result


# --- row assertions --------------------------------------------------------------------------

func _expected_retired_row(type_id: int, phase: int, refund_policy: int) -> Dictionary:
	"""The fixed 16-field shape every retired BUILD-purpose row in this suite reaches.

	`_retire()` clears every reference column to the null (slot, generation) pair and zeroes
	assigned_count, remaining_mwu, paused and work_begun regardless of purpose; only type_id,
	phase and refund_policy vary across this suite's three histories, and every history here is
	a BUILD-purpose project with §5.9's stated 4-builder cap.
	"""
	return {
		"material_container_slot": EntityDirectory.NULL_SLOT,
		"material_container_generation": EntityDirectory.NULL_GENERATION,
		"assigned_count": 0, "max_workers": Construction.MAX_BUILDERS,
		"refund_policy": refund_policy, "remaining_mwu": 0, "paused": 0,
		"present": 0, "work_begun": 0,
		"ref_slot": EntityDirectory.NULL_SLOT, "ref_generation": EntityDirectory.NULL_GENERATION,
		"subject_slot": EntityDirectory.NULL_SLOT,
		"subject_generation": EntityDirectory.NULL_GENERATION,
		"purpose": Construction.PURPOSE_BUILD, "type_id": type_id, "phase": phase,
	}


func _assert_full_row(decoded: Dictionary, expected_row: Dictionary) -> void:
	"""Assert every one of the 16 named row fields against its expected residual value."""
	for field: String in expected_row.keys():
		assert_equal(int(decoded[field]), int(expected_row[field]), "residual field '%s'" % field)


func _assert_delivered_and_live_zero(decoded: Dictionary) -> void:
	"""Assert all 4 delivered-material cells are zero, and store live_count is zero."""
	var cells: Array = decoded["delivered"]
	for index: int in 4:
		assert_equal(int(cells[index]), 0, "delivered cell %d is cleared" % index)
	assert_equal(int(decoded["live_count"]), 0, "live_count is zero after retirement")


func _assert_phase_and_policy_before_retire(ref: Vector2i, phase: int, policy: int) -> void:
	"""Assert the still-live project's public phase and refund_policy match expectations."""
	if not _require(_construction.phase_into(ref, _out), "read phase"):
		return
	assert_equal(_out.value, phase, "phase before retirement")
	if not _require(_construction.refund_policy_into(ref, _out), "read refund_policy"):
		return
	assert_equal(_out.value, policy, "refund_policy before retirement")


# --- the three real histories ------------------------------------------------------------------

func test_dirt_path_build_retires_with_expected_residual_row() -> void:
	"""Dirt-path BUILD to WORK_DONE and commit; assert the retired row's exact residual bytes."""
	assert_equal(int(Catalog.BUILDING_DEFINITION["dirt_path"]), DIRT_PATH_TYPE_ID,
		"dirt_path catalog id is frozen at 6")
	var placed: Buildings.OpResult = _buildings.place_building(
		DIRT_PATH_TYPE_ID, DIRT_PATH_TILE, 0, START_MASK)
	if not _require(placed.ok, "dirt_path placement (%s)" % placed.error):
		return
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	if not _require(opened.ok, "dirt_path project opens (%s)" % opened.error):
		return
	var row: int = opened.value
	if not _require(_construction.begin_work(opened.ref).ok, "dirt_path work begins"):
		return
	if not _require(_construction.add_work_mwu(opened.ref, 2000).ok, "dirt_path work completes"):
		return
	if not _require(_construction.commit_completion(opened.ref).ok, "dirt_path commits"):
		return
	assert_false(_construction.is_live_project(opened.ref), "retired public handle refuses")
	var decoded: Dictionary = _decode_row(_construction.state_bytes(), row)
	if not _require(bool(decoded["ok"]), "snapshot decodes (%s)" % decoded.get("error", "")):
		return
	_assert_full_row(decoded, _expected_retired_row(
		DIRT_PATH_TYPE_ID, Construction.PHASE_WORK_DONE, Construction.REFUND_PARTIAL))
	_assert_delivered_and_live_zero(decoded)


func test_open_stockpile_cancelled_before_work_retires_full_refund() -> void:
	"""open_stockpile BUILD cancelled before any delivery: REFUNDING/FULL, then retired."""
	assert_equal(int(Catalog.BUILDING_DEFINITION["open_stockpile"]), OPEN_STOCKPILE_TYPE_ID,
		"open_stockpile catalog id is frozen at 19")
	var placed: Buildings.OpResult = _buildings.place_building(
		OPEN_STOCKPILE_TYPE_ID, STOCKPILE_TILE_A, 0, START_MASK)
	if not _require(placed.ok, "stockpile placement (%s)" % placed.error):
		return
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	if not _require(opened.ok, "stockpile project opens (%s)" % opened.error):
		return
	var row: int = opened.value
	if not _require(_construction.begin_refund(opened.ref).ok, "cancel before any delivery"):
		return
	_assert_phase_and_policy_before_retire(
		opened.ref, Construction.PHASE_REFUNDING, Construction.REFUND_FULL)
	if not _require(_construction.close_refund(opened.ref).ok, "close cancellation"):
		return
	assert_false(_construction.is_live_project(opened.ref), "retired public handle refuses")
	var decoded: Dictionary = _decode_row(_construction.state_bytes(), row)
	if not _require(bool(decoded["ok"]), "snapshot decodes (%s)" % decoded.get("error", "")):
		return
	_assert_full_row(decoded, _expected_retired_row(
		OPEN_STOCKPILE_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_FULL))
	_assert_delivered_and_live_zero(decoded)


func test_open_stockpile_partial_refund_after_work_begins() -> void:
	"""Stockpile BUILD delivered, begun, 1 mwu earned, then cancelled: REFUNDING/PARTIAL."""
	assert_equal(int(Catalog.BUILDING_DEFINITION["open_stockpile"]), OPEN_STOCKPILE_TYPE_ID,
		"open_stockpile catalog id is frozen at 19")
	var placed: Buildings.OpResult = _buildings.place_building(
		OPEN_STOCKPILE_TYPE_ID, STOCKPILE_TILE_B, 0, START_MASK)
	if not _require(placed.ok, "stockpile placement (%s)" % placed.error):
		return
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	if not _require(opened.ok, "stockpile project opens (%s)" % opened.error):
		return
	var row: int = opened.value
	if not _require(_construction.deliver_material(opened.ref, 0, 4000).ok, "wood delivers"):
		return
	if not _require(_construction.begin_work(opened.ref).ok, "work begins"):
		return
	if not _require(_construction.add_work_mwu(opened.ref, 1).ok, "one mwu earned"):
		return
	if not _require(_construction.begin_refund(opened.ref).ok, "cancel after work begins"):
		return
	_assert_phase_and_policy_before_retire(
		opened.ref, Construction.PHASE_REFUNDING, Construction.REFUND_PARTIAL)
	if not _require(_construction.close_refund(opened.ref).ok, "close cancellation"):
		return
	assert_false(_construction.is_live_project(opened.ref), "retired public handle refuses")
	var decoded: Dictionary = _decode_row(_construction.state_bytes(), row)
	if not _require(bool(decoded["ok"]), "snapshot decodes (%s)" % decoded.get("error", "")):
		return
	_assert_full_row(decoded, _expected_retired_row(
		OPEN_STOCKPILE_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_PARTIAL))
	_assert_delivered_and_live_zero(decoded)


# --- the framing corruption witness --------------------------------------------------------------

func test_corrupted_snapshot_length_is_rejected_before_decode() -> void:
	"""A snapshot with one byte removed or appended fails the named length check, at row 0."""
	var bytes: PackedByteArray = _construction.state_bytes()
	var truncated: PackedByteArray = bytes.duplicate()
	truncated.remove_at(truncated.size() - 1)
	var truncated_result: Dictionary = _decode_row(truncated, 0)
	assert_false(bool(truncated_result["ok"]), "truncated snapshot refuses before decode")
	assert_equal(String(truncated_result["error"]), "TOTAL_LENGTH_MISMATCH",
		"truncated refusal is the named total-length check")
	var extended: PackedByteArray = bytes.duplicate()
	extended.append(0)
	var extended_result: Dictionary = _decode_row(extended, 0)
	assert_false(bool(extended_result["ok"]), "extended snapshot refuses before decode")
	assert_equal(String(extended_result["error"]), "TOTAL_LENGTH_MISMATCH",
		"extended refusal is the named total-length check")
