extends "res://test/framework/test_case.gd"
## Twelve REAL public Construction lifecycle histories, and the residual row each one leaves.
##
## SCOPE, STATED ONCE. This is PUBLIC COMPONENT LIFECYCLE evidence: four purposes x completion,
## cancellation before work and cancellation after work, driven end to end through the module's
## own public API. It is NOT gameplay acceptance, NOT physical inventory hauling, NOT material
## conservation, NOT refund-lot publication and NOT any statement about a savable or playable
## Construction. `deliver_material()`, `cancellation_refund_milli_into()` and
## `demolition_return_milli_into()` are the component seam the existing suite already uses; a full
## Inventory transaction test remains separate and is not credited by anything here.
##
## EVERY NUMBER IS INDEPENDENT. Bills, work totals, refund manifests and demolition returns are
## transcribed from frozen-source-facts.json and gameplay_balance.md, never read back out of the
## module under test and never derived by calling the new Columns validator or its COLUMN_*
## mirrors. open_stockpile is `wood:4000` at 60000 mWU; its demolition is 60000/4 = 15000 with a
## 50% return of 2000. The hall upgrade is `wood:20000;stone:40000;cloth:8000` at 1200000. The bed
## is `wood:2000;cloth:1000` at 20000. 80% of each, floored, is the A-suffix manifest.
##
## THE OBSERVATION METHOD IS THE REVIEWED PROBE'S, NOT A NEW ONE. The serialization-order table
## below is declared INDEPENDENTLY and matches construction.gd's own `state_bytes()` append order
## verbatim (material_container_slot .. live_count) -- which is NOT the owner contract's ordinal
## order; `present` is eighth. Every segment's byte length is measured at runtime from
## `var_to_bytes()` of a zeroed prototype of the same packed type and extent, so no Variant
## header, tag, padding or offset constant is hardcoded anywhere. The total observed length is
## checked against the sum of those measured lengths BEFORE any slice; each segment's decoded
## Variant type and element count are checked BEFORE any index. Only the target row's 16 scalars,
## its 4 delivered cells and the store's live_count are retained. Same-type/length segment swaps
## are outside this diagnostic's guarantees and no such oracle is claimed.
##
## NO PRIVATE ACCESS. No underscore field is read or written, `_retire()` is never called, no
## fake retired row is authored, and no error is suppressed. Public getters deliberately refuse a
## retired handle -- that refusal is asserted -- so the residual row is observed only through the
## module's own public snapshot.
##
## SETUP FAILURE CANNOT PASS. Every fixture step and every mutator goes through `_require()`,
## which asserts and returns the flag, and each scenario returns immediately on the first failure
## rather than continuing with an unchecked `.ref` or `.value`.

const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const NULL_REF: Vector2i = EntityDirectory.NULL_REF

## The starter world's milestone mask: M0 earned and nothing else (GDD 5.11).
const START_MASK: int = 1

## The guide's own fixture plots: the authored hall placement and a clear stockpile plot.
const HALL_TILE: int = 59 * 128 + 58
const STOCKPILE_TILE: int = 60 * 128 + 50

## Frozen catalog identities, asserted against the live catalog in `before_each()`.
const HALL_TYPE_ID: int = 12
const STOCKPILE_TYPE_ID: int = 19
const BED_TYPE_ID: int = 0
const DORMITORY_ROOM_TYPE: int = 0
const STATE_BLUEPRINT: int = 0
const STATE_BUILDING: int = 1
const STATE_ACTIVE: int = 2
const STATE_DEMOLISHING: int = 5

## Frozen bills and work, in bill-index order (frozen-source-facts.json).
const HALL_BILL: Array[int] = [100000, 60000, 12000]
const HALL_WORK: int = 2400000
const BUILD_BILL: Array[int] = [4000]
const BUILD_WORK: int = 60000
const UPGRADE_BILL: Array[int] = [20000, 40000, 8000]
const UPGRADE_WORK: int = 1200000
const FURNITURE_BILL: Array[int] = [2000, 1000]
const FURNITURE_WORK: int = 20000
const DEMOLISH_WORK: int = 15000
const DEMOLITION_RETURN_WOOD: int = 2000

## REQ-SET-126's two manifests per purpose: 100% of delivered before work, 80% floored after.
const BUILD_REFUND_FULL: Array[int] = [4000]
const BUILD_REFUND_PARTIAL: Array[int] = [3200]
const UPGRADE_REFUND_FULL: Array[int] = [20000, 40000, 8000]
const UPGRADE_REFUND_PARTIAL: Array[int] = [16000, 32000, 6400]
const FURNITURE_REFUND_FULL: Array[int] = [2000, 1000]
const FURNITURE_REFUND_PARTIAL: Array[int] = [1600, 800]

## The sixteen owner-contract fields, in canonical ordinal order, for comparison and reporting.
const FIELD_NAMES: Array[String] = [
	"present", "material_container_slot", "material_container_generation", "assigned_count",
	"max_workers", "refund_policy", "remaining_mwu", "paused", "work_begun", "ref_slot",
	"ref_generation", "subject_slot", "subject_generation", "purpose", "type_id", "phase",
]

## --- the independently declared serialization-order table (state_bytes()'s own order) -----------

const CONSTRUCTION_CAPACITY: int = 82944
const DELIVERED_CELLS: int = 331776
const KIND_I32: String = "i32"
const KIND_I64: String = "i64"
const KIND_BYTE: String = "byte"

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


class Target extends RefCounted:
	"""One opened project and every public handle its history needs after retirement."""

	var ok: bool = false
	var project: Vector2i = Vector2i(-1, 0)
	var row: int = -1
	var subject: Vector2i = Vector2i(-1, 0)
	var origin_tile: int = -1
	var base_tier: int = -1
	var room: Vector2i = Vector2i(-1, 0)
	var host: Vector2i = Vector2i(-1, 0)


var _buildings: Buildings = null
var _construction: Construction = null
var _directory: EntityDirectory = null
var _out: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""A private Construction over its own Buildings, and the frozen catalog witnesses."""
	_buildings = Buildings.new()
	_construction = Construction.new(_buildings)
	_directory = _buildings.directory()
	_out = IntMath.IntResult.new()
	assert_true(_construction.directory() == _directory,
		"Construction borrows the Building store's own shared directory")
	assert_equal(int(CatalogScript.BUILDING_DEFINITION["hall"]), HALL_TYPE_ID, "hall id is 12")
	assert_equal(int(CatalogScript.BUILDING_DEFINITION["open_stockpile"]), STOCKPILE_TYPE_ID,
		"open_stockpile id is 19")
	assert_equal(int(CatalogScript.FURNITURE_DEFINITION["bed"]), BED_TYPE_ID, "bed id is 0")
	assert_equal(int(CatalogScript.ROOM_TYPE["DORMITORY"]), DORMITORY_ROOM_TYPE,
		"DORMITORY room type is 0")
	_assert_frozen_states()


func after_each() -> void:
	"""Drop the fixture so no history inherits another's rows."""
	_construction = null
	_buildings = null
	_directory = null


func _assert_frozen_states() -> void:
	"""The four building-state ordinals these histories read, as frozen witnesses."""
	assert_equal(int(CatalogScript.BUILDING_STATE["BLUEPRINT"]), STATE_BLUEPRINT, "BLUEPRINT 0")
	assert_equal(int(CatalogScript.BUILDING_STATE["BUILDING"]), STATE_BUILDING, "BUILDING 1")
	assert_equal(int(CatalogScript.BUILDING_STATE["ACTIVE"]), STATE_ACTIVE, "ACTIVE 2")
	assert_equal(int(CatalogScript.BUILDING_STATE["DEMOLISHING"]), STATE_DEMOLISHING,
		"DEMOLISHING 5")


func _require(ok: bool, message: String) -> bool:
	"""Assert `ok` and return it, so a failed step ends its scenario before using any output."""
	assert_true(ok, message)
	return ok


# --- the length-derived, row-scoped decoder ----------------------------------------------------

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
	"""Pull this segment's needed scalar(s) for `row` into `result` and keep nothing else."""
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
	"""Decode exactly one project row's scalars from a genuine state_bytes() image.

	Refuses -- before any slice, decode or index -- when `row` is out of range or the observed
	total length disagrees with the sum of the independently measured segment lengths. Each
	segment is then type- and count-checked before its scalar(s) are read.
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
		var decoded: Variant = bytes_to_var(bytes.slice(offset, offset + length))
		if typeof(decoded) != _expected_variant_type(String(SEGMENT_KIND[name])):
			return {"ok": false, "error": "TYPE_MISMATCH:%s" % name}
		if int(decoded.size()) != int(SEGMENT_EXTENT[name]):
			return {"ok": false, "error": "COUNT_MISMATCH:%s" % name}
		_extract_scalar(result, name, decoded, row)
		offset += length
	return result


# --- fixtures, built only through the public API ------------------------------------------------

func _deliver_lines(project: Vector2i, amounts: Array[int]) -> bool:
	"""Deliver one bill, one index at a time, in the authored order."""
	for index: int in amounts.size():
		var delivered: Construction.OpResult = _construction.deliver_material(
			project, index, amounts[index])
		if not _require(delivered.ok, "bill line %d delivers (%s)" % [index, delivered.error]):
			return false
	return true


func _finish_work(project: Vector2i, work: int) -> bool:
	"""Begin work and earn the whole declared W, leaving the project in WORK_DONE."""
	if not _require(_construction.begin_work(project).ok, "work begins"):
		return false
	var step: Construction.OpResult = _construction.add_work_mwu(project, work)
	if not _require(step.ok, "the declared work is earned (%s)" % step.error):
		return false
	if not _require(step.value == 0, "no milli-WU remains outstanding"):
		return false
	if not _require(_construction.has_work_begun(project), "work_begun is latched"):
		return false
	if not _require(_construction.phase_into(project, _out), "the phase reads"):
		return false
	return _require(_out.value == Construction.PHASE_WORK_DONE, "the project is WORK_DONE")


func _assert_ready(project: Vector2i, work: int) -> bool:
	"""A fully delivered (or delivery-free) project is READY with its full declared work."""
	if not _require(_construction.phase_into(project, _out), "the phase reads"):
		return false
	if not _require(_out.value == Construction.PHASE_READY, "the project is READY"):
		return false
	if not _require(_construction.remaining_mwu_into(project, _out), "the remainder reads"):
		return false
	if not _require(_out.value == work, "the whole declared work is outstanding"):
		return false
	return _require(not _construction.has_work_begun(project), "no consumption has happened")


func _bind(target: Target, opened: Construction.OpResult, subject: Vector2i,
		is_building: bool) -> bool:
	"""Capture one opened project's public identity and check the join in both directions."""
	target.project = opened.ref
	target.row = opened.value
	target.subject = subject
	if not _require(opened.ref.y >= 1, "a live project reference carries a real generation"):
		return false
	if not _require(_directory.get_typed_row(opened.ref) == opened.value,
			"the directory agrees which typed row this project owns"):
		return false
	if not _require(_construction.subject_ref_of(opened.ref) == subject, "the subject agrees"):
		return false
	if not _require(_construction.project_of_subject(subject) == opened.ref,
			"the reverse subject join resolves"):
		return false
	if not _require(_construction.live_project_count() == 1, "exactly one project is live"):
		return false
	if not is_building:
		return true
	if not _require(_buildings.construction_ref_of_building(subject) == opened.ref,
			"the building names this exact project"):
		return false
	target.origin_tile = _buildings.origin_tile_of_building(subject).value
	target.base_tier = _buildings.tier_of_building(subject).value
	return true


func _active_hall() -> Vector2i:
	"""H fixture: one hall built to ACTIVE through the real public lifecycle."""
	var placed: Buildings.OpResult = _buildings.place_building(
		HALL_TYPE_ID, HALL_TILE, 0, START_MASK)
	if not _require(placed.ok, "the hall places (%s)" % placed.error):
		return NULL_REF
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	if not _require(opened.ok, "the hall build opens (%s)" % opened.error):
		return NULL_REF
	if not _deliver_lines(opened.ref, HALL_BILL):
		return NULL_REF
	if not _finish_work(opened.ref, HALL_WORK):
		return NULL_REF
	if not _require(_construction.commit_completion(opened.ref).ok, "the hall commits"):
		return NULL_REF
	if not _require(_buildings.state_of_building(placed.ref).value == STATE_ACTIVE,
			"the finished hall is ACTIVE"):
		return NULL_REF
	if not _require(_buildings.construction_ref_of_building(placed.ref) == NULL_REF,
			"and carries no project reference"):
		return NULL_REF
	if not _require(_construction.live_project_count() == 0, "no setup project remains"):
		return NULL_REF
	return placed.ref


func _completed_stockpile() -> Vector2i:
	"""S fixture, completed: one open_stockpile built to ACTIVE, ready to be demolished."""
	var placed: Buildings.OpResult = _buildings.place_building(
		STOCKPILE_TYPE_ID, STOCKPILE_TILE, 0, START_MASK)
	if not _require(placed.ok, "the stockpile places (%s)" % placed.error):
		return NULL_REF
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	if not _require(opened.ok, "the stockpile build opens (%s)" % opened.error):
		return NULL_REF
	if not _deliver_lines(opened.ref, BUILD_BILL):
		return NULL_REF
	if not _finish_work(opened.ref, BUILD_WORK):
		return NULL_REF
	if not _require(_construction.commit_completion(opened.ref).ok, "the stockpile commits"):
		return NULL_REF
	if not _require(_buildings.state_of_building(placed.ref).value == STATE_ACTIVE,
			"the finished stockpile is ACTIVE"):
		return NULL_REF
	if not _require(_construction.live_project_count() == 0, "no setup project remains"):
		return NULL_REF
	return placed.ref


func _designate_dormitory(host: Vector2i) -> Vector2i:
	"""The guide's four-tile interior dormitory, read from the host's own origin tile."""
	var origin: int = _buildings.origin_tile_of_building(host).value
	var tiles: PackedInt32Array = PackedInt32Array()
	for index: int in 4:
		tiles.append(origin + Buildings.MAP_TILES_X + 1 + index)
	var room: Buildings.OpResult = _buildings.designate_room(host, DORMITORY_ROOM_TYPE, tiles)
	if not _require(room.ok, "the dormitory is designated (%s)" % room.error):
		return NULL_REF
	return room.ref


func _place_bed(room: Vector2i) -> Vector2i:
	"""Place one bed on the dormitory's first tile, through the public placement API."""
	var tile: Buildings.OpResult = _buildings.room_tile_at(room, 0)
	if not _require(tile.ok, "the room's first tile reads (%s)" % tile.error):
		return NULL_REF
	var bed: Buildings.OpResult = _buildings.place_furniture(room, BED_TYPE_ID, tile.value, 0)
	if not _require(bed.ok, "the bed is placed (%s)" % bed.error):
		return NULL_REF
	return bed.ref


func _open_build_target() -> Target:
	"""S fixture: a stockpile blueprint whose whole wood line has been delivered."""
	var target: Target = Target.new()
	var placed: Buildings.OpResult = _buildings.place_building(
		STOCKPILE_TYPE_ID, STOCKPILE_TILE, 0, START_MASK)
	if not _require(placed.ok, "the stockpile places (%s)" % placed.error):
		return target
	var opened: Construction.OpResult = _construction.open_build(placed.ref)
	if not _require(opened.ok, "the BUILD project opens (%s)" % opened.error):
		return target
	if not _bind(target, opened, placed.ref, true):
		return target
	if not _deliver_lines(target.project, BUILD_BILL):
		return target
	if not _assert_ready(target.project, BUILD_WORK):
		return target
	target.ok = true
	return target


func _open_upgrade_target() -> Target:
	"""H fixture: an ACTIVE hall with its whole tier-2 package delivered."""
	var target: Target = Target.new()
	var host: Vector2i = _active_hall()
	if not _require(host != NULL_REF, "the hall fixture completes"):
		return target
	var opened: Construction.OpResult = _construction.open_upgrade(host)
	if not _require(opened.ok, "the UPGRADE project opens (%s)" % opened.error):
		return target
	if not _bind(target, opened, host, true):
		return target
	if not _deliver_lines(target.project, UPGRADE_BILL):
		return target
	if not _assert_ready(target.project, UPGRADE_WORK):
		return target
	target.ok = true
	return target


func _open_furniture_target() -> Target:
	"""F fixture: a bed placed in a hall dormitory with its whole bill delivered."""
	var target: Target = Target.new()
	target.host = _active_hall()
	if not _require(target.host != NULL_REF, "the hall fixture completes"):
		return target
	target.room = _designate_dormitory(target.host)
	if not _require(target.room != NULL_REF, "the dormitory is designated"):
		return target
	var bed: Vector2i = _place_bed(target.room)
	if not _require(bed != NULL_REF, "the bed is placed"):
		return target
	var opened: Construction.OpResult = _construction.open_furniture(bed)
	if not _require(opened.ok, "the FURNITURE project opens (%s)" % opened.error):
		return target
	if not _bind(target, opened, bed, false):
		return target
	if not _deliver_lines(target.project, FURNITURE_BILL):
		return target
	if not _assert_ready(target.project, FURNITURE_WORK):
		return target
	target.ok = true
	return target


func _open_demolition_target() -> Target:
	"""Completed S fixture, demolition opened: no delivery bill, straight into READY."""
	var target: Target = Target.new()
	var subject: Vector2i = _completed_stockpile()
	if not _require(subject != NULL_REF, "the completed stockpile fixture succeeds"):
		return target
	var opened: Construction.OpResult = _construction.open_demolition(subject)
	if not _require(opened.ok, "the DEMOLISH project opens (%s)" % opened.error):
		return target
	if not _bind(target, opened, subject, true):
		return target
	if not _require(_buildings.state_of_building(subject).value == STATE_DEMOLISHING,
			"the subject is marked DEMOLISHING"):
		return target
	if not _assert_ready(target.project, DEMOLISH_WORK):
		return target
	target.ok = true
	return target


# --- cancellation halves and their manifests ----------------------------------------------------

func _assert_refunding(project: Vector2i, remaining: int, begun: int) -> bool:
	"""A frozen cancellation: REFUNDING, the stated remainder, the stated work_begun, no workers."""
	if not _require(_construction.phase_into(project, _out), "the phase reads"):
		return false
	if not _require(_out.value == Construction.PHASE_REFUNDING, "the project is REFUNDING"):
		return false
	if not _require(_construction.remaining_mwu_into(project, _out), "the remainder reads"):
		return false
	if not _require(_out.value == remaining, "the remainder is retained exactly"):
		return false
	if not _require(_construction.has_work_begun(project) == (begun == 1),
			"work_begun matches this side of the refund boundary"):
		return false
	if not _require(_construction.assigned_count_into(project, _out), "the worker count reads"):
		return false
	return _require(_out.value == 0, "a refunding project holds no assigned builder")


func _begin_cancel_before_work(target: Target, work: int) -> bool:
	"""Suffix B: cancel from READY, with the complete bill delivered and no work earned."""
	if not _require(_construction.begin_refund(target.project).ok, "cancellation begins"):
		return false
	return _assert_refunding(target.project, work, 0)


func _begin_cancel_after_work(target: Target, work: int) -> bool:
	"""Suffix A: begin work, earn one legal test milli-WU, then cancel.

	The single milli-WU is a legal contribution used to cross REQ-SET-126's boundary; it is not a
	production rate, timing or completion claim.
	"""
	if not _require(_construction.begin_work(target.project).ok, "work begins"):
		return false
	var step: Construction.OpResult = _construction.add_work_mwu(target.project, 1)
	if not _require(step.ok, "one milli-WU is earned (%s)" % step.error):
		return false
	if not _require(step.value == work - 1, "the remainder is W minus one"):
		return false
	if not _require(_construction.phase_into(target.project, _out), "the phase reads"):
		return false
	if not _require(_out.value == Construction.PHASE_WORKING, "the project is WORKING"):
		return false
	if not _require(_construction.begin_refund(target.project).ok, "cancellation begins"):
		return false
	return _assert_refunding(target.project, work - 1, 1)


func _assert_cancellation_manifest(project: Vector2i, expected: Array[int]) -> void:
	"""REQ-SET-126's manifest, line by line, read while the project is frozen in REFUNDING."""
	for index: int in expected.size():
		assert_true(_construction.cancellation_refund_milli_into(project, index, _out),
			"cancellation manifest line %d reads" % index)
		assert_equal(_out.value, expected[index], "cancellation manifest line %d quantity" % index)


func _assert_demolition_cancellation_refuses(project: Vector2i) -> void:
	"""A cancelled demolition mints no cancellation goods: REQ-SET-126's path refuses it."""
	assert_false(_construction.cancellation_refund_milli_into(project, 0, _out),
		"a demolition has no cancellation material bill")
	assert_equal(_out.error, String(Construction.REFUSE_IS_A_DEMOLITION),
		"and refuses by its own demolition code")


func _assert_demolition_return_manifest(project: Vector2i) -> void:
	"""REQ-SET-127's return manifest, read at WORK_DONE BEFORE completion retires the handle."""
	assert_true(_construction.demolition_return_size_into(project, _out),
		"the return manifest has a size")
	assert_equal(_out.value, 1, "open_stockpile returns exactly one line")
	assert_true(_construction.demolition_return_milli_into(project, 0, _out),
		"the return line reads")
	assert_equal(_out.value, DEMOLITION_RETURN_WOOD, "50% of the original 4000 wood is 2000")


# --- retirement verification and reporting ------------------------------------------------------

func _expected_retired_row(purpose: int, type_id: int, phase: int, policy: int) -> Dictionary:
	"""The exact sixteen retained scalars a retirement in this suite must leave behind.

	Retirement clears progress, identity and work_begun, and RETAINS purpose, type_id,
	max_workers, phase and refund_policy: a retired row is not a never-used clear row, and its
	policy must never be recomputed from the work_begun retirement has already cleared.
	"""
	return {
		"present": 0,
		"material_container_slot": EntityDirectory.NULL_SLOT,
		"material_container_generation": EntityDirectory.NULL_GENERATION,
		"assigned_count": 0,
		"max_workers": Construction.MAX_BUILDERS,
		"refund_policy": policy,
		"remaining_mwu": 0,
		"paused": 0,
		"work_begun": 0,
		"ref_slot": EntityDirectory.NULL_SLOT,
		"ref_generation": EntityDirectory.NULL_GENERATION,
		"subject_slot": EntityDirectory.NULL_SLOT,
		"subject_generation": EntityDirectory.NULL_GENERATION,
		"purpose": purpose,
		"type_id": type_id,
		"phase": phase,
	}


func _assert_retired_handles(target: Target, retirement: Construction.OpResult) -> void:
	"""The public identity a retired project reports: row returned, handle dead, count zero."""
	assert_equal(retirement.value, target.row, "retirement returns the captured typed row")
	assert_equal(retirement.ref, NULL_REF, "retirement returns the null reference")
	assert_false(_directory.is_valid(target.project),
		"the project's directory reference is stale, generation and all")
	assert_false(_construction.is_live_project(target.project), "the public handle refuses")
	assert_false(_construction.phase_into(target.project, _out), "phase refuses a retired handle")
	assert_equal(_out.error, String(Construction.REFUSE_STALE_PROJECT_REF),
		"and refuses by the stale-project code rather than answering row 0")
	assert_equal(_construction.subject_ref_of(target.project), NULL_REF,
		"its subject reads as the null reference")
	assert_equal(_construction.live_project_count(), 0, "no project remains live")


func _assert_retained_row(decoded: Dictionary, expected: Dictionary) -> void:
	"""Compare all sixteen observed residual fields against their expected retained values."""
	for field: String in FIELD_NAMES:
		assert_true(expected.has(field), "the expectation covers field '%s'" % field)
		assert_equal(int(decoded[field]), int(expected[field]), "retained field '%s'" % field)


func _assert_delivered_and_live_zero(decoded: Dictionary) -> void:
	"""All four delivered-material cells are cleared, and the store holds no live project."""
	var cells: Array = decoded["delivered"]
	assert_equal(cells.size(), 4, "four delivered cells were decoded")
	for index: int in 4:
		assert_equal(int(cells[index]), 0, "delivered cell %d is cleared" % index)
	assert_equal(int(decoded["live_count"]), 0, "live_count is zero after retirement")


func _assert_row_admission(decoded: Dictionary) -> void:
	"""Admit the ONE observed retired row into an otherwise-clear image: row admission only.

	This is NOT whole-snapshot projection, and it is no same-type-swap oracle: it shows only that
	the scalars this history actually produced are locally admissible when placed at row 0 of an
	otherwise clear image. Saved identity, delivered materials and capture/apply stay elsewhere.
	"""
	var image: Construction.Columns = Construction.Columns.new()
	image.present[0] = int(decoded["present"])
	image.material_container_slot[0] = int(decoded["material_container_slot"])
	image.material_container_generation[0] = int(decoded["material_container_generation"])
	image.assigned_count[0] = int(decoded["assigned_count"])
	image.max_workers[0] = int(decoded["max_workers"])
	image.refund_policy[0] = int(decoded["refund_policy"])
	image.remaining_mwu[0] = int(decoded["remaining_mwu"])
	image.paused[0] = int(decoded["paused"])
	image.work_begun[0] = int(decoded["work_begun"])
	image.ref_slot[0] = int(decoded["ref_slot"])
	image.ref_generation[0] = int(decoded["ref_generation"])
	image.subject_slot[0] = int(decoded["subject_slot"])
	image.subject_generation[0] = int(decoded["subject_generation"])
	image.purpose[0] = int(decoded["purpose"])
	image.type_id[0] = int(decoded["type_id"])
	image.phase[0] = int(decoded["phase"])
	assert_equal(String(Construction.columns_refusal(image)), "",
		"the observed retired row is locally admissible at row 0 of a clear image")


func _emit_history(label: String, outcome: String, decoded: Dictionary,
		subject_result: String) -> void:
	"""Print one compact record of the ACTUAL observed residual row for this history."""
	var observed: Dictionary = {}
	for field: String in FIELD_NAMES:
		observed[field] = int(decoded[field])
	var record: Dictionary = {
		"scope": "public component lifecycle only; not gameplay, inventory conservation,"
			+ " material hauling or save acceptance",
		"history": label,
		"outcome": outcome,
		"subject_result": subject_result,
		"observed_row": observed,
		"delivered_milli": decoded["delivered"],
		"live_count": int(decoded["live_count"]),
	}
	print("CONSTRUCTION_REAL_HISTORY %s" % JSON.stringify(record))


func _verify_retirement(target: Target, retirement: Construction.OpResult, expected: Dictionary,
		label: String, outcome: String, subject_result: String) -> void:
	"""Assert the retired handles, decode the real snapshot row, and report what was observed."""
	_assert_retired_handles(target, retirement)
	var decoded: Dictionary = _decode_row(_construction.state_bytes(), target.row)
	if not _require(bool(decoded["ok"]),
			"the snapshot decodes (%s)" % String(decoded.get("error", ""))):
		return
	_assert_retained_row(decoded, expected)
	_assert_delivered_and_live_zero(decoded)
	_assert_row_admission(decoded)
	_emit_history(label, outcome, decoded, subject_result)


# --- subject outcomes ----------------------------------------------------------------------------

func _assert_building_survives(subject: Vector2i, origin_tile: int, state: int,
		tier: int) -> void:
	"""A surviving building subject: live, at its own tiles, unbound from any project."""
	assert_true(_buildings.is_live_building(subject), "the subject building survives")
	assert_true(_directory.is_valid(subject), "its directory reference is still valid")
	assert_equal(_buildings.state_of_building(subject).value, state, "its state")
	assert_equal(_buildings.tier_of_building(subject).value, tier, "its tier")
	assert_equal(_buildings.building_at_tile(origin_tile), subject, "its footprint is retained")
	assert_equal(_buildings.construction_ref_of_building(subject), NULL_REF,
		"and it carries no project reference")
	assert_equal(_construction.project_of_subject(subject), NULL_REF,
		"and no live project claims it")


func _assert_building_removed(subject: Vector2i, origin_tile: int) -> void:
	"""A removed building subject: gone from the store, the directory and the tile map."""
	assert_false(_buildings.is_live_building(subject), "the subject building is removed")
	assert_false(_directory.is_valid(subject), "its directory reference is stale")
	assert_equal(_buildings.building_at_tile(origin_tile), NULL_REF, "its footprint is released")


func _assert_bed_survives(target: Target) -> void:
	"""Furniture is a committed Buildings row before its project starts, and outlives it.

	Neither completion nor cancellation removes the bed: `commit_completion()` has no extra
	furniture-state transition and `close_refund()` performs no furniture removal. This asserts
	that actual source-supported lifetime rather than compensating for it.
	"""
	assert_true(_buildings.is_live_furniture(target.subject), "the bed survives")
	assert_true(_buildings.is_live_room(target.room), "its dormitory survives")
	assert_true(_buildings.is_live_building(target.host), "its hall survives")
	assert_true(_directory.is_valid(target.subject), "the bed's reference is valid")
	assert_true(_directory.is_valid(target.room), "the room's reference is valid")
	assert_true(_directory.is_valid(target.host), "the hall's reference is valid")
	assert_equal(_construction.project_of_subject(target.subject), NULL_REF,
		"and no live project claims the bed")


# --- the twelve histories -------------------------------------------------------------------------

func test_build_completion_retains_partial_policy() -> void:
	"""BUILD-C: a delivered stockpile worked to completion retires WORK_DONE / PARTIAL."""
	var target: Target = _open_build_target()
	if not _require(target.ok, "the BUILD-C fixture completes"):
		return
	if not _require(_finish_work(target.project, BUILD_WORK), "BUILD-C earns its whole work"):
		return
	var retirement: Construction.OpResult = _construction.commit_completion(target.project)
	if not _require(retirement.ok, "BUILD-C commits (%s)" % retirement.error):
		return
	_assert_building_survives(target.subject, target.origin_tile, STATE_ACTIVE, target.base_tier)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_BUILD,
		STOCKPILE_TYPE_ID, Construction.PHASE_WORK_DONE, Construction.REFUND_PARTIAL),
		"BUILD-C", "completion", "stockpile alive, ACTIVE, footprint retained")


func test_build_cancellation_before_work_retains_full_policy() -> void:
	"""BUILD-B: cancelling a fully delivered, unworked stockpile retires REFUNDING / FULL."""
	var target: Target = _open_build_target()
	if not _require(target.ok, "the BUILD-B fixture completes"):
		return
	if not _require(_begin_cancel_before_work(target, BUILD_WORK), "BUILD-B freezes"):
		return
	_assert_cancellation_manifest(target.project, BUILD_REFUND_FULL)
	var retirement: Construction.OpResult = _construction.close_refund(target.project)
	if not _require(retirement.ok, "BUILD-B closes (%s)" % retirement.error):
		return
	_assert_building_removed(target.subject, target.origin_tile)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_BUILD,
		STOCKPILE_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_FULL),
		"BUILD-B", "cancel-before-work", "stockpile destroyed, footprint released")


func test_build_cancellation_after_work_retains_partial_policy() -> void:
	"""BUILD-A: cancelling a worked stockpile retires REFUNDING / PARTIAL with an 80% manifest."""
	var target: Target = _open_build_target()
	if not _require(target.ok, "the BUILD-A fixture completes"):
		return
	if not _require(_begin_cancel_after_work(target, BUILD_WORK), "BUILD-A freezes after work"):
		return
	_assert_cancellation_manifest(target.project, BUILD_REFUND_PARTIAL)
	var retirement: Construction.OpResult = _construction.close_refund(target.project)
	if not _require(retirement.ok, "BUILD-A closes (%s)" % retirement.error):
		return
	_assert_building_removed(target.subject, target.origin_tile)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_BUILD,
		STOCKPILE_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_PARTIAL),
		"BUILD-A", "cancel-after-work", "stockpile destroyed, footprint released")


func test_upgrade_completion_retains_partial_policy_and_raises_tier() -> void:
	"""UPGRADE-C: a completed hall package retires WORK_DONE / PARTIAL and leaves tier two."""
	var target: Target = _open_upgrade_target()
	if not _require(target.ok, "the UPGRADE-C fixture completes"):
		return
	if not _require(_finish_work(target.project, UPGRADE_WORK), "UPGRADE-C earns its work"):
		return
	var retirement: Construction.OpResult = _construction.commit_completion(target.project)
	if not _require(retirement.ok, "UPGRADE-C commits (%s)" % retirement.error):
		return
	assert_true(target.base_tier != BuildingDefinitions.TIER_TWO, "the hall began below tier two")
	_assert_building_survives(target.subject, target.origin_tile, STATE_ACTIVE,
		BuildingDefinitions.TIER_TWO)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_UPGRADE,
		HALL_TYPE_ID, Construction.PHASE_WORK_DONE, Construction.REFUND_PARTIAL),
		"UPGRADE-C", "completion", "hall alive, ACTIVE, tier two")


func test_upgrade_cancellation_before_work_retains_full_policy() -> void:
	"""UPGRADE-B: cancelling a delivered, unworked package retires REFUNDING / FULL, tier intact."""
	var target: Target = _open_upgrade_target()
	if not _require(target.ok, "the UPGRADE-B fixture completes"):
		return
	if not _require(_begin_cancel_before_work(target, UPGRADE_WORK), "UPGRADE-B freezes"):
		return
	_assert_cancellation_manifest(target.project, UPGRADE_REFUND_FULL)
	var retirement: Construction.OpResult = _construction.close_refund(target.project)
	if not _require(retirement.ok, "UPGRADE-B closes (%s)" % retirement.error):
		return
	_assert_building_survives(target.subject, target.origin_tile, STATE_ACTIVE, target.base_tier)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_UPGRADE,
		HALL_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_FULL),
		"UPGRADE-B", "cancel-before-work", "hall alive, ACTIVE, tier unchanged")


func test_upgrade_cancellation_after_work_retains_partial_policy() -> void:
	"""UPGRADE-A: cancelling a worked package retires REFUNDING / PARTIAL, tier intact."""
	var target: Target = _open_upgrade_target()
	if not _require(target.ok, "the UPGRADE-A fixture completes"):
		return
	if not _require(_begin_cancel_after_work(target, UPGRADE_WORK), "UPGRADE-A freezes"):
		return
	_assert_cancellation_manifest(target.project, UPGRADE_REFUND_PARTIAL)
	var retirement: Construction.OpResult = _construction.close_refund(target.project)
	if not _require(retirement.ok, "UPGRADE-A closes (%s)" % retirement.error):
		return
	_assert_building_survives(target.subject, target.origin_tile, STATE_ACTIVE, target.base_tier)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_UPGRADE,
		HALL_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_PARTIAL),
		"UPGRADE-A", "cancel-after-work", "hall alive, ACTIVE, tier unchanged")


func test_furniture_completion_retains_partial_policy() -> void:
	"""FURNITURE-C: a completed bed project retires WORK_DONE / PARTIAL; the bed stays."""
	var target: Target = _open_furniture_target()
	if not _require(target.ok, "the FURNITURE-C fixture completes"):
		return
	if not _require(_finish_work(target.project, FURNITURE_WORK), "FURNITURE-C earns its work"):
		return
	var retirement: Construction.OpResult = _construction.commit_completion(target.project)
	if not _require(retirement.ok, "FURNITURE-C commits (%s)" % retirement.error):
		return
	_assert_bed_survives(target)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_FURNITURE,
		BED_TYPE_ID, Construction.PHASE_WORK_DONE, Construction.REFUND_PARTIAL),
		"FURNITURE-C", "completion", "bed, dormitory and hall all alive")


func test_furniture_cancellation_before_work_leaves_the_bed_in_place() -> void:
	"""FURNITURE-B: cancelling before work retires REFUNDING / FULL and removes no furniture."""
	var target: Target = _open_furniture_target()
	if not _require(target.ok, "the FURNITURE-B fixture completes"):
		return
	if not _require(_begin_cancel_before_work(target, FURNITURE_WORK), "FURNITURE-B freezes"):
		return
	_assert_cancellation_manifest(target.project, FURNITURE_REFUND_FULL)
	var retirement: Construction.OpResult = _construction.close_refund(target.project)
	if not _require(retirement.ok, "FURNITURE-B closes (%s)" % retirement.error):
		return
	_assert_bed_survives(target)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_FURNITURE,
		BED_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_FULL),
		"FURNITURE-B", "cancel-before-work", "bed, dormitory and hall all alive")


func test_furniture_cancellation_after_work_leaves_the_bed_in_place() -> void:
	"""FURNITURE-A: cancelling after work retires REFUNDING / PARTIAL and removes no furniture."""
	var target: Target = _open_furniture_target()
	if not _require(target.ok, "the FURNITURE-A fixture completes"):
		return
	if not _require(_begin_cancel_after_work(target, FURNITURE_WORK), "FURNITURE-A freezes"):
		return
	_assert_cancellation_manifest(target.project, FURNITURE_REFUND_PARTIAL)
	var retirement: Construction.OpResult = _construction.close_refund(target.project)
	if not _require(retirement.ok, "FURNITURE-A closes (%s)" % retirement.error):
		return
	_assert_bed_survives(target)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_FURNITURE,
		BED_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_PARTIAL),
		"FURNITURE-A", "cancel-after-work", "bed, dormitory and hall all alive")


func test_demolition_completion_retains_demolition_policy() -> void:
	"""DEMOLISH-C: the return manifest is read at WORK_DONE, then completion retires the row."""
	var target: Target = _open_demolition_target()
	if not _require(target.ok, "the DEMOLISH-C fixture completes"):
		return
	if not _require(_finish_work(target.project, DEMOLISH_WORK), "DEMOLISH-C earns its work"):
		return
	_assert_demolition_return_manifest(target.project)
	var retirement: Construction.OpResult = _construction.commit_completion(target.project)
	if not _require(retirement.ok, "DEMOLISH-C commits (%s)" % retirement.error):
		return
	_assert_building_removed(target.subject, target.origin_tile)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_DEMOLISH,
		STOCKPILE_TYPE_ID, Construction.PHASE_WORK_DONE, Construction.REFUND_DEMOLITION),
		"DEMOLISH-C", "completion", "stockpile destroyed, footprint released")


func test_demolition_cancellation_before_work_restores_active() -> void:
	"""DEMOLISH-B: a cancelled demolition restores ACTIVE and retains the DEMOLITION policy."""
	var target: Target = _open_demolition_target()
	if not _require(target.ok, "the DEMOLISH-B fixture completes"):
		return
	if not _require(_begin_cancel_before_work(target, DEMOLISH_WORK), "DEMOLISH-B freezes"):
		return
	_assert_demolition_cancellation_refuses(target.project)
	var retirement: Construction.OpResult = _construction.close_refund(target.project)
	if not _require(retirement.ok, "DEMOLISH-B closes (%s)" % retirement.error):
		return
	_assert_building_survives(target.subject, target.origin_tile, STATE_ACTIVE, target.base_tier)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_DEMOLISH,
		STOCKPILE_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_DEMOLITION),
		"DEMOLISH-B", "cancel-before-work", "stockpile alive, ACTIVE restored, tier unchanged")


func test_demolition_cancellation_after_work_restores_active() -> void:
	"""DEMOLISH-A: cancelling a part-worked demolition still restores ACTIVE, policy retained."""
	var target: Target = _open_demolition_target()
	if not _require(target.ok, "the DEMOLISH-A fixture completes"):
		return
	if not _require(_begin_cancel_after_work(target, DEMOLISH_WORK), "DEMOLISH-A freezes"):
		return
	_assert_demolition_cancellation_refuses(target.project)
	var retirement: Construction.OpResult = _construction.close_refund(target.project)
	if not _require(retirement.ok, "DEMOLISH-A closes (%s)" % retirement.error):
		return
	_assert_building_survives(target.subject, target.origin_tile, STATE_ACTIVE, target.base_tier)
	_verify_retirement(target, retirement, _expected_retired_row(Construction.PURPOSE_DEMOLISH,
		STOCKPILE_TYPE_ID, Construction.PHASE_REFUNDING, Construction.REFUND_DEMOLITION),
		"DEMOLISH-A", "cancel-after-work", "stockpile alive, ACTIVE restored, tier unchanged")
