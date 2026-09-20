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
## of those measured lengths BEFORE any slicing; a mismatch refuses before any slice, decode or
## index is attempted, which is the corruption witness this file exists to prove.
##
## THIS IS AN ENGINE-BOUND DIAGNOSTIC, NOT A SAVE FORMAT. No offset constant is asserted, no new
## persisted schema is proposed, and no production accessor is added; every value read here comes
## from the module's own public `state_bytes()` plus its own public row-identity return values.

const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const START_MASK: int = 1
const DIRT_PATH_TILE: int = 10 * 128 + 10
const STOCKPILE_TILE_A: int = 20 * 128 + 20
const STOCKPILE_TILE_B: int = 30 * 128 + 30

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


# --- the length-derived decoder -----------------------------------------------------------------

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


func _decode_snapshot(bytes: PackedByteArray) -> Dictionary:
	"""Slice and decode one Construction.state_bytes() image using measured segment lengths.

	Refuses -- before any slice, decode or index -- when the total observed length disagrees with
	the sum of the measured per-segment lengths. That is this file's corruption witness: a
	truncated or extended buffer is caught here, never by an out-of-range slice or a bad decode.
	"""
	var lengths: PackedInt64Array = _measure_segment_lengths()
	var total: int = 0
	for length: int in lengths:
		total += length
	if bytes.size() != total:
		return {"ok": false, "error": "TOTAL_LENGTH_MISMATCH", "segments": {}}
	var segments: Dictionary = {}
	var offset: int = 0
	for index: int in SEGMENT_NAMES.size():
		var name: String = SEGMENT_NAMES[index]
		var length: int = lengths[index]
		var piece: PackedByteArray = bytes.slice(offset, offset + length)
		var decoded: Variant = bytes_to_var(piece)
		var extent: int = int(SEGMENT_EXTENT[name])
		var expected_type: int = _expected_variant_type(String(SEGMENT_KIND[name]))
		if typeof(decoded) != expected_type:
			return {"ok": false, "error": "TYPE_MISMATCH:%s" % name, "segments": {}}
		if int(decoded.size()) != extent:
			return {"ok": false, "error": "COUNT_MISMATCH:%s" % name, "segments": {}}
		segments[name] = decoded
		offset += length
	return {"ok": true, "error": "", "segments": segments}


# --- row assertions --------------------------------------------------------------------------

func _assert_retired_row(segments: Dictionary, row: int, expected: Dictionary) -> void:
	"""Assert every named field of one decoded row against its expected residual value."""
	for field: String in expected.keys():
		var actual: int = int(segments[field][row])
		assert_equal(actual, int(expected[field]), "residual field '%s'" % field)


func _assert_delivered_and_live_zero(segments: Dictionary, row: int) -> void:
	"""Assert all 4 delivered-material cells for `row` are zero, and store live_count is zero."""
	for index: int in 4:
		var cell: int = int(segments["delivered_milli"][row * 4 + index])
		assert_equal(cell, 0, "delivered cell %d is cleared" % index)
	assert_equal(int(segments["live_count"][0]), 0, "live_count is zero after retirement")


func _assert_phase_and_policy_before_retire(ref: Vector2i, phase: int, policy: int) -> void:
	"""Assert the still-live project's public phase and refund_policy match expectations."""
	assert_true(_construction.phase_into(ref, _out), "read phase")
	assert_equal(_out.value, phase, "phase before retirement")
	assert_true(_construction.refund_policy_into(ref, _out), "read refund_policy")
	assert_equal(_out.value, policy, "refund_policy before retirement")


# --- the three real histories ------------------------------------------------------------------

func test_dirt_path_build_retires_with_expected_residual_row() -> void:
	"""Dirt-path BUILD to WORK_DONE and commit; assert the retired row's exact residual bytes."""
	var dirt_id: int = int(Catalog.BUILDING_DEFINITION["dirt_path"])
	var placed: Buildings.OpResult = _buildings.place_building(dirt_id, DIRT_PATH_TILE, 0, START_MASK)
	assert_true(placed.ok, "dirt_path placement (%s)" % placed.error)
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	assert_true(opened.ok, "dirt_path project opens (%s)" % opened.error)
	var row: int = opened.value
	assert_true(_construction.begin_work(opened.ref).ok, "dirt_path work begins")
	assert_true(_construction.add_work_mwu(opened.ref, 2000).ok, "dirt_path work completes")
	assert_true(_construction.commit_completion(opened.ref).ok, "dirt_path commits")
	assert_false(_construction.is_live_project(opened.ref), "retired public handle refuses")
	var decoded: Dictionary = _decode_snapshot(_construction.state_bytes())
	assert_true(bool(decoded["ok"]), "snapshot decodes (%s)" % decoded.get("error", ""))
	var segments: Dictionary = decoded["segments"]
	_assert_retired_row(segments, row, {
		"present": 0, "ref_slot": -1, "ref_generation": 0,
		"subject_slot": -1, "subject_generation": 0,
		"material_container_slot": -1, "material_container_generation": 0,
		"assigned_count": 0, "max_workers": 4, "refund_policy": 1,
		"remaining_mwu": 0, "paused": 0, "work_begun": 0,
		"purpose": 0, "type_id": dirt_id, "phase": 3,
	})
	_assert_delivered_and_live_zero(segments, row)


func test_open_stockpile_cancelled_before_work_retires_full_refund() -> void:
	"""open_stockpile BUILD cancelled before any delivery: REFUNDING/FULL, then retired."""
	var stockpile_id: int = int(Catalog.BUILDING_DEFINITION["open_stockpile"])
	var placed: Buildings.OpResult = _buildings.place_building(
		stockpile_id, STOCKPILE_TILE_A, 0, START_MASK)
	assert_true(placed.ok, "stockpile placement (%s)" % placed.error)
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	assert_true(opened.ok, "stockpile project opens (%s)" % opened.error)
	var row: int = opened.value
	assert_true(_construction.begin_refund(opened.ref).ok, "cancel before any delivery")
	_assert_phase_and_policy_before_retire(opened.ref, 4, 0)
	assert_true(_construction.close_refund(opened.ref).ok, "close cancellation")
	assert_false(_construction.is_live_project(opened.ref), "retired public handle refuses")
	var decoded: Dictionary = _decode_snapshot(_construction.state_bytes())
	assert_true(bool(decoded["ok"]), "snapshot decodes (%s)" % decoded.get("error", ""))
	var segments: Dictionary = decoded["segments"]
	_assert_retired_row(segments, row, {
		"phase": 4, "refund_policy": 0, "present": 0, "work_begun": 0,
		"paused": 0, "assigned_count": 0,
	})
	_assert_delivered_and_live_zero(segments, row)


func test_open_stockpile_partial_refund_after_work_begins() -> void:
	"""Stockpile BUILD delivered, begun, 1 mwu earned, then cancelled: REFUNDING/PARTIAL."""
	var stockpile_id: int = int(Catalog.BUILDING_DEFINITION["open_stockpile"])
	var placed: Buildings.OpResult = _buildings.place_building(
		stockpile_id, STOCKPILE_TILE_B, 0, START_MASK)
	assert_true(placed.ok, "stockpile placement (%s)" % placed.error)
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	assert_true(opened.ok, "stockpile project opens (%s)" % opened.error)
	var row: int = opened.value
	assert_true(_construction.deliver_material(opened.ref, 0, 4000).ok, "wood delivers")
	assert_true(_construction.begin_work(opened.ref).ok, "work begins")
	assert_true(_construction.add_work_mwu(opened.ref, 1).ok, "one mwu earned")
	assert_true(_construction.begin_refund(opened.ref).ok, "cancel after work begins")
	_assert_phase_and_policy_before_retire(opened.ref, 4, 1)
	assert_true(_construction.close_refund(opened.ref).ok, "close cancellation")
	assert_false(_construction.is_live_project(opened.ref), "retired public handle refuses")
	var decoded: Dictionary = _decode_snapshot(_construction.state_bytes())
	assert_true(bool(decoded["ok"]), "snapshot decodes (%s)" % decoded.get("error", ""))
	var segments: Dictionary = decoded["segments"]
	_assert_retired_row(segments, row, {
		"phase": 4, "refund_policy": 1, "present": 0, "work_begun": 0,
		"paused": 0, "assigned_count": 0,
	})
	_assert_delivered_and_live_zero(segments, row)


# --- the framing corruption witness --------------------------------------------------------------

func test_corrupted_snapshot_length_is_rejected_before_decode() -> void:
	"""A snapshot with one byte removed or appended fails the length check before any slicing."""
	var bytes: PackedByteArray = _construction.state_bytes()
	var truncated: PackedByteArray = bytes.duplicate()
	truncated.remove_at(truncated.size() - 1)
	var truncated_result: Dictionary = _decode_snapshot(truncated)
	assert_false(bool(truncated_result["ok"]), "truncated snapshot refuses before decode")
	var extended: PackedByteArray = bytes.duplicate()
	extended.append(0)
	var extended_result: Dictionary = _decode_snapshot(extended)
	assert_false(bool(extended_result["ok"]), "extended snapshot refuses before decode")
