extends "res://test/framework/test_case.gd"
## DEMO-CONTAIN-R01 #6's split completion in `construction.gd` (decision 0535).
##
## `commit_completion()` removes a demolition's building and retires its row in one call; #6 places
## the 50% return BETWEEN the two, so the coordinator uses the three doors tested here:
## `demolition_commit_refusal()` (the read-only proof), `remove_demolished_subject()` (step 4) and
## `retire_demolition()` (step 6), plus `demolition_return_into()`, the snapshot's manifest in one
## call. Every refusal leaves Construction, Buildings and the directory byte-identical.

const Construction := preload("res://scripts/core/construction.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")

const HALL_TILE: int = 59 * 128 + 58
const WELL_TILE: int = 40 * 128 + 40
const START_MASK: int = 1

var _buildings: Buildings = null
var _construction: Construction = null
var _out: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""A private Construction store over its own Building store."""
	_buildings = Buildings.new()
	_construction = Construction.new(_buildings)
	_out = IntMath.IntResult.new()


func after_each() -> void:
	"""Drop the fixture."""
	_construction = null
	_buildings = null


# --- fixtures --------------------------------------------------------------------------------

func _active(key: String, tile: int) -> Vector2i:
	"""Place one ACTIVE building of `key` at `tile`."""
	var placed: Buildings.OpResult = _buildings.place_building(
		int(CatalogScript.BUILDING_DEFINITION[key]), tile, 0, START_MASK)
	assert_true(placed.ok, "%s places (%s)" % [key, placed.error])
	assert_true(_buildings.set_building_state(placed.ref, Construction.STATE_ACTIVE).ok, "ACTIVE")
	return placed.ref


func _opened(building: Vector2i) -> Vector2i:
	"""Open a demolition of `building` and return the project ref."""
	var opened: Construction.OpResult = _construction.open_demolition(building)
	assert_true(opened.ok, "the demolition opens (%s)" % opened.error)
	return opened.ref


func _finished(building: Vector2i) -> Vector2i:
	"""Open a demolition of `building`, work it to PHASE_WORK_DONE, and return the project."""
	var project: Vector2i = _opened(building)
	assert_true(_construction.begin_work(project).ok, "work begins")
	assert_true(_construction.remaining_mwu_into(project, _out), "the remainder reads")
	assert_true(_construction.add_work_mwu(project, _out.value).ok, "and the work is done")
	return project


func _snapshot() -> PackedByteArray:
	"""Construction, the directory and the building store's live counts and footprint map."""
	var out: PackedByteArray = _construction.state_bytes()
	out.append_array(_buildings.directory().state_bytes())
	var fields: PackedInt64Array = PackedInt64Array([_buildings.live_building_count(),
		_buildings.live_room_count(), _buildings.live_furniture_count()])
	for tile: int in Buildings.TILE_COUNT:
		var occupant: Vector2i = _buildings.building_at_tile(tile)
		if occupant != EntityDirectory.NULL_REF:
			fields.append_array(PackedInt64Array([tile, occupant.x, occupant.y,
				_buildings.state_of_building(occupant).value,
				_buildings.construction_ref_of_building(occupant).x]))
	out.append_array(var_to_bytes(fields))
	return out


func _add_room(building: Vector2i) -> Vector2i:
	"""Designate a one-tile dormitory just inside the building's origin corner."""
	var tile: int = _buildings.origin_tile_of_building(building).value + Buildings.MAP_TILES_X + 1
	var room: Buildings.OpResult = _buildings.designate_room(building,
		int(CatalogScript.ROOM_TYPE["DORMITORY"]), PackedInt32Array([tile]))
	assert_true(room.ok, "a room is designated (%s)" % room.error)
	return room.ref


# --- demolition_commit_refusal ---------------------------------------------------------------

func test_the_commit_proof_passes_only_a_finished_demolition_with_its_building() -> void:
	"""PHASE_WORK_DONE and a standing subject; nothing is written either way."""
	var well: Vector2i = _active("well", WELL_TILE)
	var project: Vector2i = _opened(well)
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.demolition_commit_refusal(project), Construction.REFUSE_WRONG_PHASE,
		"an unworked demolition is not done")
	assert_true(_snapshot() == before, "and the read wrote nothing")
	assert_true(_construction.begin_work(project).ok, "work begins")
	before = _snapshot()
	assert_equal(_construction.demolition_commit_refusal(project), Construction.REFUSE_WRONG_PHASE,
		"a working demolition is not done either")
	assert_true(_snapshot() == before, "nothing written")
	assert_true(_construction.remaining_mwu_into(project, _out), "remainder")
	assert_true(_construction.add_work_mwu(project, _out.value).ok, "done")
	before = _snapshot()
	assert_equal(_construction.demolition_commit_refusal(project), Construction.REFUSE_NONE,
		"a finished demolition with its building standing passes")
	assert_true(_snapshot() == before, "and passing writes nothing either")


func test_the_commit_proof_refuses_stale_refs_and_other_purposes() -> void:
	"""A stale ref, a BUILD project and a lost subject each refuse by their own code."""
	assert_equal(_construction.demolition_commit_refusal(EntityDirectory.NULL_REF),
		Construction.REFUSE_STALE_PROJECT_REF, "the null ref")
	var placed: Buildings.OpResult = _buildings.place_building(
		int(CatalogScript.BUILDING_DEFINITION["well"]), WELL_TILE, 0, START_MASK)
	var build: Construction.OpResult = _construction.open_build(placed.ref)
	assert_equal(_construction.demolition_commit_refusal(build.ref),
		Construction.REFUSE_NOT_A_DEMOLITION, "a BUILD project is not a demolition")
	var hall: Vector2i = _active("hall", HALL_TILE)
	var project: Vector2i = _finished(hall)
	assert_true(_construction.remove_demolished_subject(project).ok, "the hall goes")
	assert_equal(_construction.demolition_commit_refusal(project), Construction.REFUSE_SUBJECT_LOST,
		"once the building is gone the proof refuses SUBJECT_LOST")


# --- remove_demolished_subject (step 4) -----------------------------------------------------

func test_step_four_removes_the_building_and_keeps_the_project_row() -> void:
	"""The building and its footprint go; the row stays live, WORK_DONE, for step 6."""
	var well: Vector2i = _active("well", WELL_TILE)
	var project: Vector2i = _finished(well)
	var removed: Construction.OpResult = _construction.remove_demolished_subject(project)
	assert_true(removed.ok, "step 4 (%s)" % removed.error)
	assert_equal(removed.ref, project, "it answers the still-live project")
	assert_false(_buildings.is_live_building(well), "the well is gone")
	assert_equal(_buildings.building_at_tile(WELL_TILE), EntityDirectory.NULL_REF, "tiles freed")
	assert_true(_construction.is_live_project(project), "the project row is kept")
	assert_true(_construction.phase_into(project, _out), "phase")
	assert_equal(_out.value, Construction.PHASE_WORK_DONE, "still WORK_DONE")
	assert_equal(_construction.live_project_count(), 1, "one live project")


func test_step_four_refuses_a_building_with_rooms_and_restores_its_link() -> void:
	"""BUILDING_HAS_ROOMS is demolish_building's own; the back-reference is restored."""
	var hall: Vector2i = _active("hall", HALL_TILE)
	_add_room(hall)
	var project: Vector2i = _finished(hall)
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.remove_demolished_subject(project).error,
		Buildings.REFUSE_BUILDING_HAS_ROOMS, "the rooms block it")
	assert_true(_snapshot() == before, "byte-identical")
	assert_equal(_buildings.construction_ref_of_building(hall), project, "the link stands")


func test_step_four_refuses_an_unfinished_demolition_writing_nothing() -> void:
	"""The proof runs first: WRONG_PHASE before anything is unlinked."""
	var well: Vector2i = _active("well", WELL_TILE)
	var project: Vector2i = _opened(well)
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.remove_demolished_subject(project).error,
		Construction.REFUSE_WRONG_PHASE, "not done")
	assert_true(_snapshot() == before, "byte-identical")


# --- retire_demolition (step 6) ---------------------------------------------------------------

func test_step_six_retires_the_project_once_its_building_is_gone() -> void:
	"""The row, its directory slot and its paid-ledger snapshot are freed."""
	var well: Vector2i = _active("well", WELL_TILE)
	var project: Vector2i = _finished(well)
	assert_true(_construction.remove_demolished_subject(project).ok, "step 4")
	var retired: Construction.OpResult = _construction.retire_demolition(project)
	assert_true(retired.ok, "step 6 (%s)" % retired.error)
	assert_false(_construction.is_live_project(project), "the row is gone")
	assert_false(_buildings.directory().is_valid(project), "and its directory slot")
	assert_equal(_construction.live_project_count(), 0, "no live project")
	assert_equal(_construction.retire_demolition(project).error,
		Construction.REFUSE_STALE_PROJECT_REF, "a second retire finds nothing")


func test_step_six_refuses_while_the_building_still_stands() -> void:
	"""SUBJECT_STILL_STANDING by name: no DEMOLISHING building is left without its project."""
	var well: Vector2i = _active("well", WELL_TILE)
	var project: Vector2i = _finished(well)
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.retire_demolition(project).error,
		Construction.REFUSE_SUBJECT_STANDING, "the well stands")
	assert_true(_snapshot() == before, "byte-identical")


func test_step_six_refuses_other_purposes_and_unfinished_work() -> void:
	"""NOT_A_DEMOLITION for a BUILD project; WRONG_PHASE for an unfinished demolition."""
	var placed: Buildings.OpResult = _buildings.place_building(
		int(CatalogScript.BUILDING_DEFINITION["well"]), WELL_TILE, 0, START_MASK)
	var build: Construction.OpResult = _construction.open_build(placed.ref)
	assert_equal(_construction.retire_demolition(build.ref).error,
		Construction.REFUSE_NOT_A_DEMOLITION, "a BUILD project")
	var hall: Vector2i = _active("hall", HALL_TILE)
	var project: Vector2i = _opened(hall)
	assert_equal(_construction.retire_demolition(project).error, Construction.REFUSE_WRONG_PHASE,
		"an unfinished demolition")


# --- demolition_return_into -------------------------------------------------------------------

func test_the_whole_manifest_matches_the_line_readers_and_the_preview() -> void:
	"""One call, the same lines as the per-line readers and as admit's preview, tier 2 included."""
	var hall: Vector2i = _active("hall", HALL_TILE)
	assert_true(_buildings.set_building_tier(hall, BuildingDefinitions.TIER_TWO).ok, "tier 2")
	var preview_keys: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var preview_milli: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])
	assert_true(_construction.demolition_return_preview_into(hall, preview_keys, preview_milli,
		_out), "the preview reads")
	var project: Vector2i = _opened(hall)
	var keys: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var milli: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])
	assert_true(_construction.demolition_return_into(project, keys, milli, _out), "it reads")
	assert_equal(_out.value, 3, "three lines: wood, stone, cloth")
	for line: int in 3:
		var one: IntMath.IntResult = IntMath.IntResult.new()
		assert_true(_construction.demolition_return_milli_into(project, line, one), "line")
		assert_equal(milli[line], one.value, "line %d agrees with the line reader" % line)
		assert_equal(milli[line], preview_milli[line], "and with the preview")
		assert_equal(keys[line], preview_keys[line], "key %d agrees" % line)
	assert_equal(milli[0], 60000, "wood: half of base 100000 plus upgrade 20000")


func test_the_whole_manifest_refuses_bad_inputs() -> void:
	"""A stale ref, a non-demolition and undersized buffers all refuse by name."""
	var keys: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var milli: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])
	assert_false(_construction.demolition_return_into(EntityDirectory.NULL_REF, keys, milli, _out),
		"stale")
	assert_equal(StringName(_out.error), Construction.REFUSE_STALE_PROJECT_REF, "by name")
	var placed: Buildings.OpResult = _buildings.place_building(
		int(CatalogScript.BUILDING_DEFINITION["well"]), WELL_TILE, 0, START_MASK)
	var build: Construction.OpResult = _construction.open_build(placed.ref)
	assert_false(_construction.demolition_return_into(build.ref, keys, milli, _out), "BUILD")
	assert_equal(StringName(_out.error), Construction.REFUSE_NOT_A_DEMOLITION, "by name")
	var hall: Vector2i = _active("hall", HALL_TILE)
	var project: Vector2i = _opened(hall)
	assert_false(_construction.demolition_return_into(project, PackedInt32Array([0, 0, 0, 0, 0]), milli,
		_out), "five key cells")
	assert_equal(StringName(_out.error), Construction.REFUSE_MANIFEST_BUFFER, "buffer")
	assert_false(_construction.demolition_return_into(project, keys, PackedInt64Array([0, 0, 0, 0, 0]),
		_out), "five quantity cells")
	assert_equal(StringName(_out.error), Construction.REFUSE_MANIFEST_BUFFER, "buffer")


# --- decision 0536: Brendan's rulings on 0535's P1-P3 -------------------------------------------

func _piece_in(building: Vector2i, key: String) -> Vector2i:
	"""One piece of `key` in a fresh one-tile dormitory just inside `building`'s origin corner."""
	var room: Vector2i = _add_room(building)
	var tile: int = _buildings.origin_tile_of_building(building).value + Buildings.MAP_TILES_X + 1
	var made: Buildings.OpResult = _buildings.place_furniture(room,
		int(CatalogScript.FURNITURE_DEFINITION[key]), tile, 0)
	assert_true(made.ok, "a %s is placed (%s)" % [key, made.error])
	return made.ref


func _quarter(key: String) -> int:
	"""A quarter of one piece's §4.3 WU, from the definitions."""
	@warning_ignore("integer_division") return _construction.definitions().furniture_work_mwu_of(
		int(CatalogScript.FURNITURE_DEFINITION[key])) / 4


func _removal_done(piece: Vector2i) -> Vector2i:
	"""Open a piece's removal and finish its work."""
	var opened: Construction.OpResult = _construction.open_furniture_removal(piece)
	assert_true(opened.ok, "the removal opens (%s)" % opened.error)
	assert_true(_construction.begin_work(opened.ref).ok, "work begins")
	assert_true(_construction.remaining_mwu_into(opened.ref, _out), "remainder")
	assert_true(_construction.add_work_mwu(opened.ref, _out.value).ok, "done")
	return opened.ref


func test_p3_the_store_level_doors_refuse_a_demolition_by_name() -> void:
	"""commit_completion() and close_refund() refuse COORDINATOR_ONLY, writing nothing."""
	var well: Vector2i = _active("well", WELL_TILE)
	var project: Vector2i = _finished(well)
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.commit_completion(project).error,
		Construction.REFUSE_COORDINATOR_ONLY, "completion")
	assert_true(_construction.begin_refund(project).ok, "refunding")
	var refunding: PackedByteArray = _snapshot()
	assert_equal(_construction.close_refund(project).error, Construction.REFUSE_COORDINATOR_ONLY,
		"cancellation")
	assert_true(_snapshot() == refunding, "byte-identical")
	assert_false(before == refunding, "(begin_refund itself moved the phase)")


func test_p3_the_coordinators_cancellation_door_restores_active() -> void:
	"""close_demolition_refund(): REFUNDING only, removals only; a demolition's building is ACTIVE."""
	var well: Vector2i = _active("well", WELL_TILE)
	var project: Vector2i = _opened(well)
	assert_equal(_construction.close_demolition_refund(project).error,
		Construction.REFUSE_WRONG_PHASE, "not yet refunding")
	assert_true(_construction.begin_refund(project).ok, "refunding")
	assert_true(_construction.close_demolition_refund(project).ok, "closes")
	assert_equal(_buildings.state_of_building(well).value, Construction.STATE_ACTIVE, "ACTIVE")
	assert_equal(_construction.live_project_count(), 0, "retired")
	assert_equal(_construction.close_demolition_refund(project).error,
		Construction.REFUSE_STALE_PROJECT_REF, "a second close finds nothing")
	var placed: Buildings.OpResult = _buildings.place_building(
		int(CatalogScript.BUILDING_DEFINITION["well"]), 70 * 128 + 70, 0, START_MASK)
	var build: Construction.OpResult = _construction.open_build(placed.ref)
	assert_true(_construction.begin_refund(build.ref).ok, "a BUILD refunding")
	assert_equal(_construction.close_demolition_refund(build.ref).error,
		Construction.REFUSE_NOT_A_DEMOLITION, "is not this door's")


func test_p1_a_demolitions_work_adds_a_quarter_of_each_pieces_wu() -> void:
	"""Brendan's sub-question: removing furniture adds a quarter of the piece's build WU."""
	var hall: Vector2i = _active("hall", HALL_TILE)
	_piece_in(hall, "bed")
	assert_equal(_construction.demolition_open_refusal(hall), Construction.REFUSE_NONE, "proved")
	var project: Vector2i = _opened(hall)
	assert_true(_construction.remaining_mwu_into(project, _out), "remainder")
	assert_equal(_out.value, 600000 + _quarter("bed"), "the hall's quarter plus the bed's")


func test_p1_the_return_adds_each_pieces_half() -> void:
	"""The line readers, the whole-manifest call and the preview agree, the bed included."""
	var hall: Vector2i = _active("hall", HALL_TILE)
	_piece_in(hall, "bed")
	var keys: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var milli: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])
	assert_true(_construction.demolition_return_preview_into(hall, keys, milli, _out), "preview")
	assert_equal(_out.value, 3, "wood, stone, cloth")
	assert_equal(milli[0], 50000 + 1000, "wood: the hall's half and the bed's")
	assert_equal(milli[2], 6000 + 500, "cloth: the hall's half and the bed's")
	var project: Vector2i = _opened(hall)
	assert_true(_construction.demolition_return_milli_into(project, 2, _out), "line reader")
	assert_equal(_out.value, 6500, "agrees")
	assert_true(_construction.demolition_return_key_index_into(project, 2, _out), "key reader")
	assert_equal(_out.value, Construction.MATERIAL_KEYS.find(&"cloth"), "cloth")


func test_p2_a_piece_removal_opens_with_a_quarter_of_its_wu_and_returns_half_its_bill() -> void:
	"""PURPOSE_REMOVE_FURNITURE: READY, DEMOLITION policy, base key = the piece's type."""
	var hall: Vector2i = _active("hall", HALL_TILE)
	var bed: Vector2i = _piece_in(hall, "bed")
	assert_equal(_construction.furniture_removal_open_refusal(bed), Construction.REFUSE_NONE, "ok")
	var opened: Construction.OpResult = _construction.open_furniture_removal(bed)
	assert_true(opened.ok, "opens (%s)" % opened.error)
	assert_true(_construction.purpose_into(opened.ref, _out), "purpose")
	assert_equal(_out.value, Construction.PURPOSE_REMOVE_FURNITURE, "a removal")
	assert_true(_construction.phase_into(opened.ref, _out), "phase")
	assert_equal(_out.value, Construction.PHASE_READY, "no delivery")
	assert_true(_construction.refund_policy_into(opened.ref, _out), "policy")
	assert_equal(_out.value, Construction.REFUND_DEMOLITION, "the 50% policy")
	assert_true(_construction.remaining_mwu_into(opened.ref, _out), "work")
	assert_equal(_out.value, _quarter("bed"), "a quarter of the bed's WU")
	assert_true(_construction.paid_base_type_into(opened.ref, _out), "base key")
	assert_equal(_out.value, int(CatalogScript.FURNITURE_DEFINITION["bed"]), "the bed's own type")
	assert_equal(_buildings.construction_ref_of_building(hall), EntityDirectory.NULL_REF,
		"the building is not linked to a piece's removal")
	var keys: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var milli: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0, 0])
	assert_true(_construction.demolition_return_into(opened.ref, keys, milli, _out), "return")
	assert_equal(_out.value, 2, "wood and cloth")
	assert_equal(milli[0], 1000, "half the bed's wood")
	assert_equal(milli[1], 500, "half its cloth")
	assert_true(_construction.furniture_removal_return_preview_into(bed, keys, milli, _out), "preview")
	assert_equal(milli[1], 500, "the preview agrees")


func test_p2_a_piece_removal_refuses_by_name_writing_nothing() -> void:
	"""Stale, already carrying a project, in use, and a full CONSTRUCTION kind."""
	var hall: Vector2i = _active("hall", HALL_TILE)
	var bed: Vector2i = _piece_in(hall, "bed")
	var before: PackedByteArray = _snapshot()
	assert_equal(_construction.open_furniture_removal(Vector2i(5, 1)).error,
		Construction.REFUSE_STALE_FURNITURE_REF, "stale")
	assert_true(_snapshot() == before, "byte-identical")
	var resident: Vector2i = _buildings.directory().create(EntityDirectory.KIND_RESIDENT)
	assert_true(_buildings.set_furniture_user(bed, resident).ok, "somebody sleeps in it")
	before = _snapshot()
	assert_equal(_construction.open_furniture_removal(bed).error,
		Construction.REFUSE_FURNITURE_IN_USE, "in use")
	assert_true(_snapshot() == before, "byte-identical")
	assert_true(_buildings.set_furniture_user(bed, EntityDirectory.NULL_REF).ok, "they get up")
	assert_true(_construction.open_furniture(bed).ok, "its construction project")
	before = _snapshot()
	assert_equal(_construction.open_furniture_removal(bed).error,
		Construction.REFUSE_ALREADY_UNDER_CONSTRUCTION, "already has a project")
	assert_true(_snapshot() == before, "byte-identical")
	assert_equal(_construction.furniture_removal_open_refusal(Vector2i(5, 1)),
		Construction.REFUSE_STALE_FURNITURE_REF, "the read-only proof agrees")


func test_p2_a_finished_piece_removal_removes_the_piece_and_retires() -> void:
	"""The subject step removes the piece, keeps the row; retirement then frees it."""
	var hall: Vector2i = _active("hall", HALL_TILE)
	var bed: Vector2i = _piece_in(hall, "bed")
	var project: Vector2i = _removal_done(bed)
	assert_equal(_construction.demolition_commit_refusal(project), Construction.REFUSE_NONE, "ok")
	assert_equal(_construction.retire_demolition(project).error,
		Construction.REFUSE_SUBJECT_STANDING, "the bed still stands")
	assert_equal(_construction.commit_completion(project).error,
		Construction.REFUSE_COORDINATOR_ONLY, "and the store door refuses")
	assert_true(_construction.begin_refund(project).ok, "refunding")
	assert_equal(_construction.close_refund(project).error, Construction.REFUSE_COORDINATOR_ONLY,
		"as does the store's cancellation door, for a piece's removal too")
	assert_true(_construction.close_demolition_refund(project).ok, "the coordinator's door closes")
	project = _removal_done(bed)
	assert_true(_construction.remove_demolished_subject(project).ok, "the bed goes")
	assert_false(_buildings.is_live_furniture(bed), "gone")
	assert_true(_buildings.is_live_building(hall), "the hall stands")
	assert_true(_construction.retire_demolition(project).ok, "retired")
	assert_equal(_construction.live_project_count(), 0, "no live project")


func test_p2_the_removal_purpose_is_furniture_subject_and_a_removal() -> void:
	"""The two predicates, the bill size and the cancellation-manifest refusal."""
	assert_true(Construction.is_removal(Construction.PURPOSE_DEMOLISH), "demolish")
	assert_true(Construction.is_removal(Construction.PURPOSE_REMOVE_FURNITURE), "remove")
	assert_false(Construction.is_removal(Construction.PURPOSE_FURNITURE), "furniture build")
	assert_true(Construction.is_furniture_subject(Construction.PURPOSE_REMOVE_FURNITURE), "piece")
	assert_false(Construction.is_furniture_subject(Construction.PURPOSE_DEMOLISH), "building")
	var bed_id: int = int(CatalogScript.FURNITURE_DEFINITION["bed"])
	assert_true(_construction.bill_size_into(Construction.PURPOSE_REMOVE_FURNITURE, bed_id, _out),
		"a removal has a (delivery) bill size")
	assert_equal(_out.value, 0, "of zero")
	assert_false(_construction.bill_size_into(Construction.LIVE_PURPOSE_COUNT, bed_id, _out),
		"past the live purposes")
	assert_equal(StringName(_out.error), Construction.REFUSE_UNKNOWN_PURPOSE, "unknown")
	var hall: Vector2i = _active("hall", HALL_TILE)
	var project: Vector2i = _removal_done(_piece_in(hall, "bed"))
	assert_false(_construction.cancellation_refund_milli_into(project, 0, _out), "no 100/80%")
	assert_equal(StringName(_out.error), Construction.REFUSE_IS_A_DEMOLITION, "by name")


func test_p2_the_frozen_local_validation_fails_closed_on_a_removal_row() -> void:
	"""ADR 0186 pins purposes 0..3: an image carrying a removal row refuses COLUMN_ENUM."""
	assert_equal(Construction.PURPOSE_COUNT, Construction.SOURCE_PURPOSE_COUNT,
		"the frozen anchor still matches")
	var image: Construction.Columns = Construction.Columns.new(true)
	assert_equal(Construction.columns_refusal(image), &"", "the clear image is accepted")
	image.purpose[0] = Construction.PURPOSE_REMOVE_FURNITURE
	assert_equal(Construction.columns_refusal(image), Construction.REFUSE_COLUMN_ENUM,
		"a removal row is outside the frozen enum: fail closed")
