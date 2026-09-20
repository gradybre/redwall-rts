extends "res://test/framework/test_case.gd"
## Independent functional suite for res://scripts/core/starter_structures.gd, INIT-C-PREP-R01v1.
##
## Every expected value below is transcribed as literal data from the frozen
## docs/validation/evidence/starter-integration-planning-2026-09-20/layout-reference.json plus
## the contract's explicit prose -- never loaded at runtime, and never obtained by calling the
## production producer as an oracle. Only Catalog/BuildingDefinitions compiled ids are read
## (explicitly permitted). A revealed defect is a finding, not license to weaken an assertion.

const StarterStructures := preload("res://scripts/core/starter_structures.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const PlanClass := StarterStructures.Plan

# --- independent oracle data --------------------------------------------------------------------

const BUILDING_ORACLE: Array = [
	{"key": "hall", "x": 58, "z": 59, "fx": 12, "fz": 10},
	{"key": "open_stockpile", "x": 50, "z": 60, "fx": 4, "fz": 4},
	{"key": "open_stockpile", "x": 50, "z": 65, "fx": 4, "fz": 4},
	{"key": "open_stockpile", "x": 70, "z": 60, "fx": 4, "fz": 4},
	{"key": "open_stockpile", "x": 70, "z": 65, "fx": 4, "fz": 4},
	{"key": "well", "x": 64, "z": 54, "fx": 2, "fz": 2},
	{"key": "workbench", "x": 58, "z": 54, "fx": 3, "fz": 3},
]

const ROOM_KEYS: Array = ["DORMITORY", "KITCHEN", "COMMON", "PANTRY"]
const ROOM_COUNTS: Array = [40, 10, 25, 5]
const ROOM_OFFSETS: Array = [0, 40, 50, 75]
## Inclusive local (min_x, max_x, min_z, max_z) per room ordinal.
const ROOM_BOUNDS: Array = [
	[0, 4, 0, 7], [5, 9, 0, 1], [5, 9, 2, 6], [5, 9, 7, 7],
]

## [key, origin_local, room_ordinal, footprint_local(Array[int]), candidates_local(Array[int])]
const FURNITURE_ORACLE: Array = [
	{"key": "bed", "origin": 0, "room": 0, "footprint": [0], "candidates": [10]},
	{"key": "bed", "origin": 1, "room": 0, "footprint": [1], "candidates": [11]},
	{"key": "bed", "origin": 2, "room": 0, "footprint": [2], "candidates": [12]},
	{"key": "bed", "origin": 3, "room": 0, "footprint": [3], "candidates": [4, 13]},
	{"key": "kitchen_bench", "origin": 6, "room": 1, "footprint": [6, 7], "candidates": [5, 16, 17]},
	{"key": "hearth", "origin": 8, "room": 1, "footprint": [8, 9], "candidates": [18]},
	{"key": "shelf", "origin": 19, "room": 1, "footprint": [19], "candidates": [18]},
	{"key": "bed", "origin": 20, "room": 0, "footprint": [20], "candidates": [10, 30]},
	{"key": "bed", "origin": 21, "room": 0, "footprint": [21], "candidates": [11, 31]},
	{"key": "bed", "origin": 22, "room": 0, "footprint": [22], "candidates": [12, 32]},
	{"key": "bed", "origin": 23, "room": 0, "footprint": [23], "candidates": [13, 24, 33]},
	{"key": "seat", "origin": 26, "room": 2, "footprint": [26], "candidates": [16, 25, 36]},
	{"key": "seat", "origin": 27, "room": 2, "footprint": [27], "candidates": [17, 37]},
	{"key": "seat", "origin": 28, "room": 2, "footprint": [28], "candidates": [18, 38]},
	{"key": "seat", "origin": 29, "room": 2, "footprint": [29], "candidates": [39]},
	{"key": "bed", "origin": 40, "room": 0, "footprint": [40], "candidates": [30, 50]},
	{"key": "bed", "origin": 41, "room": 0, "footprint": [41], "candidates": [31, 51]},
	{"key": "bed", "origin": 42, "room": 0, "footprint": [42], "candidates": [32, 52]},
	{"key": "bed", "origin": 43, "room": 0, "footprint": [43], "candidates": [33, 44, 53]},
	{"key": "seat", "origin": 46, "room": 2, "footprint": [46], "candidates": [36, 45]},
	{"key": "seat", "origin": 47, "room": 2, "footprint": [47], "candidates": [37]},
	{"key": "seat", "origin": 48, "room": 2, "footprint": [48], "candidates": [38]},
	{"key": "seat", "origin": 49, "room": 2, "footprint": [49], "candidates": [39]},
	{"key": "seat", "origin": 56, "room": 2, "footprint": [56], "candidates": [55, 66]},
	{"key": "seat", "origin": 57, "room": 2, "footprint": [57], "candidates": [67]},
	{"key": "seat", "origin": 58, "room": 2, "footprint": [58], "candidates": [68]},
	{"key": "seat", "origin": 59, "room": 2, "footprint": [59], "candidates": [69]},
	{"key": "shelf", "origin": 76, "room": 3, "footprint": [76], "candidates": [66, 75]},
	{"key": "shelf", "origin": 77, "room": 3, "footprint": [77], "candidates": [67]},
	{"key": "shelf", "origin": 78, "room": 3, "footprint": [78], "candidates": [68]},
	{"key": "shelf", "origin": 79, "room": 3, "footprint": [79], "candidates": [69]},
]

const BED_ROWS: Array = [0, 1, 2, 3, 7, 8, 9, 10, 15, 16, 17, 18]
const SEAT_ROWS: Array = [11, 12, 13, 14, 19, 20, 21, 22, 23, 24, 25, 26]
## The three pantry shelves whose sole candidate is a COMMON-owned tile (row 27's shelf has two
## candidates and is deliberately excluded, per the contract's "three pantry shelves" wording).
const PANTRY_SOLE_COMMON_ROWS: Array = [28, 29, 30]
const PANTRY_SOLE_COMMON_TILES: Array = [67, 68, 69]

## [local_a, local_b, kind_key, room_ordinal_a, room_ordinal_b], sorted ascending by local_a.
const EDGE_ORACLE: Array = [
	{"a": 4, "b": 5, "kind": "interior_partition", "room_a": 0, "room_b": 1},
	{"a": 14, "b": 15, "kind": "interior_partition", "room_a": 0, "room_b": 1},
	{"a": 24, "b": 25, "kind": "interior_partition", "room_a": 0, "room_b": 2},
	{"a": 34, "b": 35, "kind": "interior_partition", "room_a": 0, "room_b": 2},
	{"a": 44, "b": 45, "kind": "interior_door", "room_a": 0, "room_b": 2},
	{"a": 54, "b": 55, "kind": "interior_partition", "room_a": 0, "room_b": 2},
	{"a": 64, "b": 65, "kind": "interior_partition", "room_a": 0, "room_b": 2},
	{"a": 74, "b": 75, "kind": "interior_partition", "room_a": 0, "room_b": 3},
]

const EXIT_INTERIOR_LOCAL: int = 75
const EXIT_WALL_GLOBAL: int = 68 * 128 + 64
const EXIT_EXTERIOR_GLOBAL: int = 69 * 128 + 64


## Test-only fault injection: legal GDScript subclassing per the repository's own
## test_commands_arena_restore.gd FaultScheduler/FaultCommands pattern. `fail_mode` is a
## test-only bool toggle so ONE instance can be driven through success -> injected failure ->
## success again, proving last_refusal() clears and prior output is fully overwritten either way.
class FaultProducer extends StarterStructures:
	var fail_mode: bool = false
	func _fill_authored_plan(plan: StarterStructures.Plan) -> void:
		super._fill_authored_plan(plan)
		if fail_mode:
			plan.set_exit_field(StarterStructures.Plan.EXIT_COL_INTERIOR, 999)


# --- shared helpers ------------------------------------------------------------------------------

func _fresh_plan() -> StarterStructures.Plan:
	"""A newly, genuinely prepared canonical Plan. A production failure here is a real finding."""
	var producer := StarterStructures.new()
	var plan := StarterStructures.Plan.new()
	var ok: bool = producer.prepare_into(plan)
	if not ok:
		fail("canonical prepare_into failed: %s" % producer.last_refusal())
	return plan


func _oracle_local_to_global(local: int, hall_x: int, hall_z: int) -> int:
	"""Interior-local -> exterior-global tile, per the contract's own stated arithmetic."""
	var interior_x: int = hall_x + 1
	var interior_z: int = hall_z + 1
	var lx: int = local % 10
	var lz: int = local / 10
	return (interior_z + lz) * 128 + (interior_x + lx)


func _oracle_room_of_local(local: int) -> int:
	"""Which room ordinal owns an interior-local tile, per the contract's own bounds table."""
	var x: int = local % 10
	var z: int = local / 10
	for ordinal in ROOM_BOUNDS.size():
		var b: Array = ROOM_BOUNDS[ordinal]
		if x >= b[0] and x <= b[1] and z >= b[2] and z <= b[3]:
			return ordinal
	return -1


func _case(desc: String, mutator: Callable, expected: StringName) -> Dictionary:
	return {"desc": desc, "mutator": mutator, "expected": expected}


func _snapshot_plan(p: StarterStructures.Plan) -> Dictionary:
	"""An independent copy of all ten arrays, so a later comparison proves nonmutation."""
	return {
		"buildings": p.buildings.duplicate(),
		"rooms": p.rooms.duplicate(),
		"room_tiles": p.room_tiles.duplicate(),
		"furniture": p.furniture.duplicate(),
		"footprints": p.footprints.duplicate(),
		"candidate_access_tiles": p.candidate_access_tiles.duplicate(),
		"edges": p.edges.duplicate(),
		"exit_tiles": p.exit_tiles.duplicate(),
		"bed_furniture_ordinals": p.bed_furniture_ordinals.duplicate(),
		"header": p.header.duplicate(),
	}


func _assert_plan_matches_snapshot(p: StarterStructures.Plan, snapshot: Dictionary, message: String) -> void:
	assert_equal(p.buildings, snapshot["buildings"], message + " (buildings)")
	assert_equal(p.rooms, snapshot["rooms"], message + " (rooms)")
	assert_equal(p.room_tiles, snapshot["room_tiles"], message + " (room_tiles)")
	assert_equal(p.furniture, snapshot["furniture"], message + " (furniture)")
	assert_equal(p.footprints, snapshot["footprints"], message + " (footprints)")
	assert_equal(p.candidate_access_tiles, snapshot["candidate_access_tiles"], message + " (candidate_access_tiles)")
	assert_equal(p.edges, snapshot["edges"], message + " (edges)")
	assert_equal(p.exit_tiles, snapshot["exit_tiles"], message + " (exit_tiles)")
	assert_equal(p.bed_furniture_ordinals, snapshot["bed_furniture_ordinals"], message + " (bed_furniture_ordinals)")
	assert_equal(p.header, snapshot["header"], message + " (header)")


func _assert_all_equal(arr: PackedInt32Array, value: int, message: String) -> void:
	for i in arr.size():
		assert_equal(arr[i], value, "%s at index %d" % [message, i])


func _run_case_matrix(cases: Array) -> void:
	"""For every case: mutate a fresh plan, snapshot it, validate, and prove plan_refusal is a
	pure read-only validator -- it must not mutate the (already-corrupted) plan, and repeating
	the call must return the identical refusal code and still not mutate the plan."""
	for entry in cases:
		var plan := _fresh_plan()
		entry["mutator"].call(plan)
		var snapshot := _snapshot_plan(plan)
		var code: StringName = StarterStructures.plan_refusal(plan)
		assert_equal(code, entry["expected"], entry["desc"])
		_assert_plan_matches_snapshot(plan, snapshot, entry["desc"] + " -- plan_refusal must not mutate")
		var code2: StringName = StarterStructures.plan_refusal(plan)
		assert_equal(code2, entry["expected"], entry["desc"] + " -- repeated plan_refusal is deterministic")
		_assert_plan_matches_snapshot(plan, snapshot, entry["desc"] + " -- second plan_refusal must not mutate")


func _resize_field(p: StarterStructures.Plan, name: String, delta: int) -> void:
	match name:
		"buildings": p.buildings.resize(p.buildings.size() + delta)
		"rooms": p.rooms.resize(p.rooms.size() + delta)
		"room_tiles": p.room_tiles.resize(p.room_tiles.size() + delta)
		"furniture": p.furniture.resize(p.furniture.size() + delta)
		"footprints": p.footprints.resize(p.footprints.size() + delta)
		"candidate_access_tiles": p.candidate_access_tiles.resize(p.candidate_access_tiles.size() + delta)
		"edges": p.edges.resize(p.edges.size() + delta)
		"exit_tiles": p.exit_tiles.resize(p.exit_tiles.size() + delta)
		"bed_furniture_ordinals": p.bed_furniture_ordinals.resize(p.bed_furniture_ordinals.size() + delta)
		"header": p.header.resize(p.header.size() + delta)


## Two- and three-statement mutators, extracted into ordinary top-level functions with normal
## single-level indentation so no multi-line lambda body ever appears inside an Array literal --
## the pattern that produced the earlier 'Unindent doesn't match' parse failure.

func _swap_room_tiles_0_1(p: StarterStructures.Plan) -> void:
	var tmp: int = p.room_tiles[0]
	p.room_tiles[0] = p.room_tiles[1]
	p.room_tiles[1] = tmp


func _swap_bed_ordinals_0_1(p: StarterStructures.Plan) -> void:
	var tmp: int = p.bed_furniture_ordinals[0]
	p.bed_furniture_ordinals[0] = p.bed_furniture_ordinals[1]
	p.bed_furniture_ordinals[1] = tmp


func _misalign_edge_row1_onto_partition_column(p: StarterStructures.Plan) -> void:
	p.set_edge_field(1, PlanClass.EDGE_COL_TILE_A, 4)
	p.set_edge_field(1, PlanClass.EDGE_COL_TILE_B, 5)


func _unsort_candidates_5_6(p: StarterStructures.Plan) -> void:
	var tmp: int = p.candidate_access_tiles[5]
	p.candidate_access_tiles[5] = p.candidate_access_tiles[6]
	p.candidate_access_tiles[6] = tmp


func _omit_row4_third_candidate(p: StarterStructures.Plan) -> void:
	"""Legitimately remove candidate arena index 7 (value 17, the kitchen bench's real
	down-neighbour) by compacting the WHOLE arena left by one starting there, lowering row 4's
	ownown candidate_count from 3 to 2, decrementing every LATER furniture row's candidate_offset
	by one, and lowering the header's candidate_used by one -- so every offset, count, and the
	unused tail stay internally coherent, and the ONLY thing wrong is that row 4's declared
	candidate set (size 2) is smaller than its real, independently-recomputed complete
	neighbour set (size 3). Closes TEST-R02-6: this is not the out-of-range-sentinel substitution
	the earlier version of this case used."""
	var removed_index: int = 7
	for i in range(removed_index, PlanClass.CANDIDATE_ROW_COUNT - 1):
		p.candidate_access_tiles[i] = p.candidate_access_tiles[i + 1]
	p.candidate_access_tiles[PlanClass.CANDIDATE_ROW_COUNT - 1] = PlanClass.NO_VALUE
	p.set_furniture_field(4, PlanClass.FURNITURE_COL_CANDIDATE_COUNT, 2)
	for row in range(5, PlanClass.FURNITURE_ROW_COUNT):
		var offset: int = p.furniture_field(row, PlanClass.FURNITURE_COL_CANDIDATE_OFFSET)
		p.set_furniture_field(row, PlanClass.FURNITURE_COL_CANDIDATE_OFFSET, offset - 1)
	p.set_header_field(PlanClass.HEADER_COL_CANDIDATE_USED, PlanClass.CANDIDATE_USED_COUNT - 1)


# --- structural constants sanity ------------------------------------------------------------------

func test_plan_row_counts_match_the_contract() -> void:
	assert_equal(PlanClass.BUILDING_ROW_COUNT, 7, "seven buildings")
	assert_equal(PlanClass.ROOM_ROW_COUNT, 4, "four rooms")
	assert_equal(PlanClass.ROOM_TILES_ROW_COUNT, 80, "eighty interior tiles")
	assert_equal(PlanClass.FURNITURE_ROW_COUNT, 31, "thirty-one furniture instances")
	assert_equal(PlanClass.FOOTPRINTS_ROW_COUNT, 33, "thirty-three floor tiles")
	assert_equal(PlanClass.CANDIDATE_ROW_COUNT, 132, "candidate arena extent")
	assert_equal(PlanClass.EDGE_ROW_COUNT, 8, "eight edges")
	assert_equal(PlanClass.BED_ROW_COUNT, 12, "twelve bed ordinals")
	assert_equal(PlanClass.PLAN_TOTAL_BYTES, 2480, "declared total payload bytes")


# --- null gates and fresh-default refusal -----------------------------------------------------

func test_null_refusals() -> void:
	var producer := StarterStructures.new()
	assert_false(producer.prepare_into(null), "prepare_into(null) must refuse")
	assert_equal(producer.last_refusal(), StarterStructures.REFUSE_PLAN_NULL, "prepare_into(null) code")
	assert_equal(StarterStructures.plan_refusal(null), StarterStructures.REFUSE_PLAN_NULL, "plan_refusal(null) code")


func test_fresh_default_plan_is_all_sentinel_and_refuses() -> void:
	var plan := StarterStructures.Plan.new()
	_assert_all_equal(plan.buildings, PlanClass.NO_VALUE, "fresh buildings")
	_assert_all_equal(plan.rooms, PlanClass.NO_VALUE, "fresh rooms")
	_assert_all_equal(plan.room_tiles, PlanClass.NO_VALUE, "fresh room_tiles")
	_assert_all_equal(plan.furniture, PlanClass.NO_VALUE, "fresh furniture")
	_assert_all_equal(plan.footprints, PlanClass.NO_VALUE, "fresh footprints")
	_assert_all_equal(plan.candidate_access_tiles, PlanClass.NO_VALUE, "fresh candidate_access_tiles")
	_assert_all_equal(plan.edges, PlanClass.NO_VALUE, "fresh edges")
	_assert_all_equal(plan.exit_tiles, PlanClass.NO_VALUE, "fresh exit_tiles")
	_assert_all_equal(plan.bed_furniture_ordinals, PlanClass.NO_VALUE, "fresh bed_furniture_ordinals")
	_assert_all_equal(plan.header, 0, "fresh header")
	var code: StringName = StarterStructures.plan_refusal(plan)
	assert_equal(code, StarterStructures.REFUSE_BUILDING_LAYOUT,
		"an all-default fresh plan must deterministically refuse at the building gate")


# --- shape gates ---------------------------------------------------------------------------------

func test_shape_gates() -> void:
	var array_names: Array = [
		"buildings", "rooms", "room_tiles", "furniture", "footprints",
		"candidate_access_tiles", "edges", "exit_tiles", "bed_furniture_ordinals", "header",
	]
	var cases: Array = []
	for name in array_names:
		cases.append(_case("undersized %s" % name, func(p): _resize_field(p, name, -1), StarterStructures.REFUSE_PLAN_SHAPE))
		cases.append(_case("oversized %s" % name, func(p): _resize_field(p, name, 1), StarterStructures.REFUSE_PLAN_SHAPE))
	_run_case_matrix(cases)


# --- building layout gates -----------------------------------------------------------------------

func test_building_layout_gates() -> void:
	var cases: Array = [
		_case("negative type_id", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_TYPE_ID, -1), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("type_id beyond the compiled domain", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_TYPE_ID, 999), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("origin_tile negative", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_GLOBAL_ORIGIN_TILE, -1), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("origin_tile beyond the map", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_GLOBAL_ORIGIN_TILE, 128 * 128), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("rotation negative", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_ROTATION, -1), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("rotation beyond 3", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_ROTATION, 4), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("tier below minimum", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_TIER, 0), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("desired_state negative", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_DESIRED_STATE, -1), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("desired_state beyond the domain", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_DESIRED_STATE, 999), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("footprint_x zero", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_FOOTPRINT_X, 0), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("footprint_z negative", func(p): p.set_building_field(1, PlanClass.BUILDING_COL_FOOTPRINT_Z, -1), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("required_unlock negative", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_REQUIRED_UNLOCK, -1), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("required_unlock beyond the Milestone domain", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_REQUIRED_UNLOCK, 999), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("origin pushes footprint off the map edge", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_GLOBAL_ORIGIN_TILE, 127 * 128 + 120), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("stockpile row relocated onto the hall footprint", func(p): p.set_building_field(1, PlanClass.BUILDING_COL_GLOBAL_ORIGIN_TILE, 59 * 128 + 58), StarterStructures.REFUSE_BUILDING_LAYOUT),
	]
	_run_case_matrix(cases)


# --- room layout gates ---------------------------------------------------------------------------

func test_room_layout_gates() -> void:
	var cases: Array = [
		_case("duplicate room type across two ordinals", func(p): p.set_room_field(1, PlanClass.ROOM_COL_TYPE_ID, p.room_field(0, PlanClass.ROOM_COL_TYPE_ID)), StarterStructures.REFUSE_ROOM_LAYOUT),
		_case("room type beyond the protected RoomType domain", func(p): p.set_room_field(0, PlanClass.ROOM_COL_TYPE_ID, 999), StarterStructures.REFUSE_ROOM_LAYOUT),
		_case("tile_offset drifts from the accumulated run", func(p): p.set_room_field(1, PlanClass.ROOM_COL_TILE_OFFSET, 41), StarterStructures.REFUSE_ROOM_LAYOUT),
		_case("tile_count zero", func(p): p.set_room_field(3, PlanClass.ROOM_COL_TILE_COUNT, 0), StarterStructures.REFUSE_ROOM_LAYOUT),
		_case("duplicate tile within a room's own run", func(p): p.room_tiles[1] = p.room_tiles[0], StarterStructures.REFUSE_ROOM_LAYOUT),
		_case("a room tile that is not part of the interior", func(p): p.room_tiles[0] = 0, StarterStructures.REFUSE_ROOM_LAYOUT),
		_case("a room's own tile run is not strictly ascending", func(p): _swap_room_tiles_0_1(p), StarterStructures.REFUSE_ROOM_LAYOUT),
	]
	_run_case_matrix(cases)


# --- furniture layout gates -----------------------------------------------------------------------

func test_furniture_layout_gates() -> void:
	var cases: Array = [
		_case("duplicate origin_local across two instances", func(p): p.set_furniture_field(1, PlanClass.FURNITURE_COL_ORIGIN_LOCAL, p.furniture_field(0, PlanClass.FURNITURE_COL_ORIGIN_LOCAL)), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("declared room_ordinal disagrees with the actual owning room", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_ROOM_ORDINAL, 2), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("room_ordinal beyond the plan's own four rooms", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_ROOM_ORDINAL, 9), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("invalid rotation", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_ROTATION, 5), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("footprint tile stored does not match the origin's own geometry", func(p): p.footprints[0] = 55, StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("origin_local beyond the interior", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_ORIGIN_LOCAL, 999), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("a rotated bench mismatches its stored footprint tiles", func(p): p.set_furniture_field(4, PlanClass.FURNITURE_COL_ROTATION, 1), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("duplicate bed ordinal", func(p): p.bed_furniture_ordinals[1] = p.bed_furniture_ordinals[0], StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("bed ordinals not strictly ascending", func(p): _swap_bed_ordinals_0_1(p), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("a bed ordinal points at a non-bed instance", func(p): p.bed_furniture_ordinals[0] = 4, StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("footprint_offset negative", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_FOOTPRINT_OFFSET, -1), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("footprint_offset at int32 max", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_FOOTPRINT_OFFSET, 2147483647), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("footprint_count negative", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_FOOTPRINT_COUNT, -1), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("footprint_count zero where one tile is required", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_FOOTPRINT_COUNT, 0), StarterStructures.REFUSE_FURNITURE_LAYOUT),
		_case("footprint_count at int32 max", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_FOOTPRINT_COUNT, 2147483647), StarterStructures.REFUSE_FURNITURE_LAYOUT),
	]
	_run_case_matrix(cases)


# --- edge layout gates -----------------------------------------------------------------------------

func test_edge_layout_gates() -> void:
	var cases: Array = [
		_case("edge run not strictly ascending by tile_a", func(p): _misalign_edge_row1_onto_partition_column(p), StarterStructures.REFUSE_EDGE_LAYOUT),
		_case("tile_b is not tile_a's immediate horizontal neighbour", func(p): p.set_edge_field(0, PlanClass.EDGE_COL_TILE_B, 50), StarterStructures.REFUSE_EDGE_LAYOUT),
		_case("edge moved off the shared partition column", func(p): p.set_edge_field(0, PlanClass.EDGE_COL_TILE_A, 6), StarterStructures.REFUSE_EDGE_LAYOUT),
		_case("wrong room_a for the actual left endpoint", func(p): p.set_edge_field(0, PlanClass.EDGE_COL_ROOM_A, 2), StarterStructures.REFUSE_EDGE_LAYOUT),
		_case("wrong room_b for the actual right endpoint", func(p): p.set_edge_field(0, PlanClass.EDGE_COL_ROOM_B, 0), StarterStructures.REFUSE_EDGE_LAYOUT),
		_case("kind_id beyond the compiled FurnitureDefinition domain", func(p): p.set_edge_field(0, PlanClass.EDGE_COL_KIND_ID, 999), StarterStructures.REFUSE_EDGE_LAYOUT),
		_case("tile_a out of range", func(p): p.set_edge_field(0, PlanClass.EDGE_COL_TILE_A, -1), StarterStructures.REFUSE_EDGE_LAYOUT),
		_case("edge row collapsed onto an earlier row's tile", func(p): p.set_edge_field(1, PlanClass.EDGE_COL_TILE_A, 4), StarterStructures.REFUSE_EDGE_LAYOUT),
	]
	_run_case_matrix(cases)


# --- exit gates, one code per segment ---------------------------------------------------------------

func test_exit_interior_gates() -> void:
	var cases: Array = [
		_case("interior_local negative", func(p): p.set_exit_field(PlanClass.EXIT_COL_INTERIOR, -1), StarterStructures.REFUSE_EXIT_INTERIOR),
		_case("interior_local beyond the interior tile count", func(p): p.set_exit_field(PlanClass.EXIT_COL_INTERIOR, 999), StarterStructures.REFUSE_EXIT_INTERIOR),
		_case("interior_local sits on an occupied furniture tile", func(p): p.set_exit_field(PlanClass.EXIT_COL_INTERIOR, 0), StarterStructures.REFUSE_EXIT_INTERIOR),
	]
	_run_case_matrix(cases)


func test_exit_wall_gates() -> void:
	var cases: Array = [
		_case("wall_band_global out of map range", func(p): p.set_exit_field(PlanClass.EXIT_COL_WALL, -1), StarterStructures.REFUSE_EXIT_WALL),
		_case("wall_band_global not adjacent to the interior tile", func(p): p.set_exit_field(PlanClass.EXIT_COL_WALL, 0), StarterStructures.REFUSE_EXIT_WALL),
		_case("wall_band_global is itself still an interior tile", func(p): p.set_exit_field(PlanClass.EXIT_COL_WALL, 67 * 128 + 64), StarterStructures.REFUSE_EXIT_WALL),
	]
	_run_case_matrix(cases)


func test_exit_exterior_gates() -> void:
	var cases: Array = [
		_case("exterior_global out of map range", func(p): p.set_exit_field(PlanClass.EXIT_COL_EXTERIOR, 999999), StarterStructures.REFUSE_EXIT_EXTERIOR),
		_case("exterior_global not adjacent to the wall tile", func(p): p.set_exit_field(PlanClass.EXIT_COL_EXTERIOR, 0), StarterStructures.REFUSE_EXIT_EXTERIOR),
		_case("exterior_global is itself still an interior tile", func(p): p.set_exit_field(PlanClass.EXIT_COL_EXTERIOR, 67 * 128 + 64), StarterStructures.REFUSE_EXIT_EXTERIOR),
		_case("exterior_global lands inside a building footprint", func(p): p.set_exit_field(PlanClass.EXIT_COL_EXTERIOR, 68 * 128 + 63), StarterStructures.REFUSE_EXIT_EXTERIOR),
	]
	_run_case_matrix(cases)


# --- walk connectivity --------------------------------------------------------------------------

func test_walk_disconnected_sole_door_replaced() -> void:
	var plan := _fresh_plan()
	var partition_id: int = Catalog.FURNITURE_DEFINITION["interior_partition"]
	# Edge row 4 is the authored (44,45) door -- the only DORMITORY <-> rest-of-interior opening.
	plan.set_edge_field(4, PlanClass.EDGE_COL_KIND_ID, partition_id)
	var code: StringName = StarterStructures.plan_refusal(plan)
	assert_equal(code, StarterStructures.REFUSE_WALK_DISCONNECTED,
		"replacing the sole door with a partition must disconnect the dormitory")


# --- access candidate gates -----------------------------------------------------------------------

func test_access_candidate_gates() -> void:
	var cases: Array = [
		_case("candidate_offset drifts from the accumulated arena", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_CANDIDATE_OFFSET, 1), StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("candidate_count zero", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_CANDIDATE_COUNT, 0), StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("a genuinely missing legal neighbour, with a coherently compacted arena", func(p): _omit_row4_third_candidate(p), StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("duplicate candidate entry within a run", func(p): p.candidate_access_tiles[6] = p.candidate_access_tiles[5], StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("candidate run not sorted ascending", func(p): _unsort_candidates_5_6(p), StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("an occupied tile listed as a candidate", func(p): p.candidate_access_tiles[4] = 6, StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("a non-neighbour tile listed as a candidate", func(p): p.candidate_access_tiles[3] = 79, StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("dirty unused candidate tail", func(p): p.candidate_access_tiles[51] = 0, StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("candidate_offset negative", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_CANDIDATE_OFFSET, -1), StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("candidate_offset at int32 max", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_CANDIDATE_OFFSET, 2147483647), StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("candidate_count negative", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_CANDIDATE_COUNT, -1), StarterStructures.REFUSE_ACCESS_CANDIDATES),
		_case("candidate_count at int32 max", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_CANDIDATE_COUNT, 2147483647), StarterStructures.REFUSE_ACCESS_CANDIDATES),
	]
	_run_case_matrix(cases)


# --- final authored-layout gate ------------------------------------------------------------------

func test_authored_layout_final_gate_header_drift() -> void:
	var plan := _fresh_plan()
	plan.set_header_field(PlanClass.HEADER_COL_VERSION, 2)
	var code: StringName = StarterStructures.plan_refusal(plan)
	assert_equal(code, StarterStructures.REFUSE_AUTHORED_LAYOUT,
		"a structurally valid but non-authored header must reach only the final exact-match gate")


func test_authored_layout_final_gate_stockpile_relocated_to_legal_disjoint_footprint() -> void:
	var plan := _fresh_plan()
	# Global tile (90,90): fully in-map (94 <= 128 on both axes) and disjoint from every one of
	# the other six authored footprints (hall x58-69/z59-68, the other three stockpiles,
	# the well and the workbench), so every structural gate still passes and only the final
	# exact-authored-fixture comparison can fail.
	plan.set_building_field(1, PlanClass.BUILDING_COL_GLOBAL_ORIGIN_TILE, 90 * 128 + 90)
	var code: StringName = StarterStructures.plan_refusal(plan)
	assert_equal(code, StarterStructures.REFUSE_AUTHORED_LAYOUT,
		"a structurally legal but relocated stockpile must reach only the final exact-match gate")


func test_plan_refusal_accepts_canonical_plan() -> void:
	var plan := _fresh_plan()
	var snapshot := _snapshot_plan(plan)
	var code: StringName = StarterStructures.plan_refusal(plan)
	assert_equal(code, StarterStructures.REFUSE_NONE, "the canonical authored plan must validate cleanly")
	_assert_plan_matches_snapshot(plan, snapshot, "a successful plan_refusal must not mutate the plan")


# --- exact array contents -------------------------------------------------------------------------

func test_exact_building_contents() -> void:
	var plan := _fresh_plan()
	var active_state: int = Catalog.BUILDING_STATE["ACTIVE"]
	for row in BUILDING_ORACLE.size():
		var entry: Dictionary = BUILDING_ORACLE[row]
		var expected_type: int = Catalog.BUILDING_DEFINITION[entry["key"]]
		assert_equal(plan.building_field(row, PlanClass.BUILDING_COL_TYPE_ID), expected_type, "building %d type_id" % row)
		assert_equal(plan.building_field(row, PlanClass.BUILDING_COL_GLOBAL_ORIGIN_TILE), int(entry["z"]) * 128 + int(entry["x"]), "building %d origin" % row)
		assert_equal(plan.building_field(row, PlanClass.BUILDING_COL_ROTATION), 0, "building %d rotation" % row)
		assert_equal(plan.building_field(row, PlanClass.BUILDING_COL_TIER), 1, "building %d tier" % row)
		assert_equal(plan.building_field(row, PlanClass.BUILDING_COL_DESIRED_STATE), active_state, "building %d desired_state" % row)
		assert_equal(plan.building_field(row, PlanClass.BUILDING_COL_FOOTPRINT_X), entry["fx"], "building %d footprint_x" % row)
		assert_equal(plan.building_field(row, PlanClass.BUILDING_COL_FOOTPRINT_Z), entry["fz"], "building %d footprint_z" % row)
		assert_equal(plan.building_field(row, PlanClass.BUILDING_COL_REQUIRED_UNLOCK), 0, "building %d required_unlock" % row)


func test_exact_room_contents() -> void:
	var plan := _fresh_plan()
	var hall_x := 58
	var hall_z := 59
	for ordinal in ROOM_KEYS.size():
		var expected_type: int = Catalog.ROOM_TYPE[ROOM_KEYS[ordinal]]
		assert_equal(plan.room_field(ordinal, PlanClass.ROOM_COL_TYPE_ID), expected_type, "room %d type" % ordinal)
		assert_equal(plan.room_field(ordinal, PlanClass.ROOM_COL_TILE_OFFSET), ROOM_OFFSETS[ordinal], "room %d offset" % ordinal)
		assert_equal(plan.room_field(ordinal, PlanClass.ROOM_COL_TILE_COUNT), ROOM_COUNTS[ordinal], "room %d count" % ordinal)
		var bounds: Array = ROOM_BOUNDS[ordinal]
		var idx: int = ROOM_OFFSETS[ordinal]
		for z in range(int(bounds[2]), int(bounds[3]) + 1):
			for x in range(int(bounds[0]), int(bounds[1]) + 1):
				var expected_global: int = _oracle_local_to_global(z * 10 + x, hall_x, hall_z)
				assert_equal(plan.room_tiles[idx], expected_global, "room %d tile at index %d" % [ordinal, idx])
				idx += 1


func test_exact_furniture_contents() -> void:
	var plan := _fresh_plan()
	var footprint_index := 0
	var candidate_index := 0
	var bed_index := 0
	for row in FURNITURE_ORACLE.size():
		var entry: Dictionary = FURNITURE_ORACLE[row]
		var expected_type: int = Catalog.FURNITURE_DEFINITION[entry["key"]]
		assert_equal(plan.furniture_field(row, PlanClass.FURNITURE_COL_TYPE_ID), expected_type, "furniture %d type" % row)
		assert_equal(plan.furniture_field(row, PlanClass.FURNITURE_COL_ROOM_ORDINAL), entry["room"], "furniture %d room" % row)
		assert_equal(plan.furniture_field(row, PlanClass.FURNITURE_COL_ORIGIN_LOCAL), entry["origin"], "furniture %d origin" % row)
		assert_equal(plan.furniture_field(row, PlanClass.FURNITURE_COL_ROTATION), 0, "furniture %d rotation" % row)
		assert_equal(plan.furniture_field(row, PlanClass.FURNITURE_COL_FOOTPRINT_OFFSET), footprint_index, "furniture %d footprint_offset" % row)
		var footprint: Array = entry["footprint"]
		assert_equal(plan.furniture_field(row, PlanClass.FURNITURE_COL_FOOTPRINT_COUNT), footprint.size(), "furniture %d footprint_count" % row)
		for tile in footprint:
			assert_equal(plan.footprints[footprint_index], tile, "footprint tile at index %d" % footprint_index)
			footprint_index += 1
		assert_equal(plan.furniture_field(row, PlanClass.FURNITURE_COL_CANDIDATE_OFFSET), candidate_index, "furniture %d candidate_offset" % row)
		var candidates: Array = entry["candidates"]
		assert_equal(plan.furniture_field(row, PlanClass.FURNITURE_COL_CANDIDATE_COUNT), candidates.size(), "furniture %d candidate_count" % row)
		for tile in candidates:
			assert_equal(plan.candidate_access_tiles[candidate_index], tile, "candidate tile at index %d" % candidate_index)
			candidate_index += 1
		if entry["key"] == "bed":
			assert_equal(plan.bed_furniture_ordinals[bed_index], row, "bed ordinal slot %d" % bed_index)
			bed_index += 1
	assert_equal(footprint_index, 33, "total footprint tiles used")
	assert_equal(candidate_index, 51, "total candidate tiles used")
	assert_equal(bed_index, 12, "total bed instances")
	for tail in range(candidate_index, 132):
		assert_equal(plan.candidate_access_tiles[tail], -1, "unused candidate tail at index %d" % tail)


func test_exact_edge_contents() -> void:
	var plan := _fresh_plan()
	for row in EDGE_ORACLE.size():
		var entry: Dictionary = EDGE_ORACLE[row]
		var expected_kind: int = Catalog.FURNITURE_DEFINITION[entry["kind"]]
		assert_equal(plan.edge_field(row, PlanClass.EDGE_COL_TILE_A), entry["a"], "edge %d tile_a" % row)
		assert_equal(plan.edge_field(row, PlanClass.EDGE_COL_TILE_B), entry["b"], "edge %d tile_b" % row)
		assert_equal(plan.edge_field(row, PlanClass.EDGE_COL_KIND_ID), expected_kind, "edge %d kind" % row)
		assert_equal(plan.edge_field(row, PlanClass.EDGE_COL_ROOM_A), entry["room_a"], "edge %d room_a" % row)
		assert_equal(plan.edge_field(row, PlanClass.EDGE_COL_ROOM_B), entry["room_b"], "edge %d room_b" % row)


func test_exact_exit_and_header_contents() -> void:
	var plan := _fresh_plan()
	assert_equal(plan.exit_field(PlanClass.EXIT_COL_INTERIOR), EXIT_INTERIOR_LOCAL, "exit interior_local")
	assert_equal(plan.exit_field(PlanClass.EXIT_COL_WALL), EXIT_WALL_GLOBAL, "exit wall_band_global")
	assert_equal(plan.exit_field(PlanClass.EXIT_COL_EXTERIOR), EXIT_EXTERIOR_GLOBAL, "exit exterior_global")
	assert_equal(plan.header_field(PlanClass.HEADER_COL_VERSION), 1, "header version")
	assert_equal(plan.header_field(PlanClass.HEADER_COL_CANDIDATE_USED), 51, "header candidate_used")
	assert_equal(plan.header_field(PlanClass.HEADER_COL_FOOTPRINT_USED), 33, "header footprint_used")
	assert_equal(plan.header_field(PlanClass.HEADER_COL_WALK_TILE_COUNT), 47, "header walk_tile_count")
	var total_elements: int = plan.buildings.size() + plan.rooms.size() + plan.room_tiles.size() \
		+ plan.furniture.size() + plan.footprints.size() + plan.candidate_access_tiles.size() \
		+ plan.edges.size() + plan.exit_tiles.size() + plan.bed_furniture_ordinals.size() + plan.header.size()
	assert_equal(total_elements * 4, 2480, "total logical payload bytes, independently summed")


func test_room_ordinals_are_not_the_protected_room_type_ids() -> void:
	var plan := _fresh_plan()
	assert_equal(PlanClass.ROOM_ROW_COUNT, 4, "plan carries four room ordinals")
	assert_true(Catalog.ROOM_TYPE.size() > PlanClass.ROOM_ROW_COUNT,
		"the protected RoomType domain carries more members than the plan's room ordinals")
	var expected_type_ids: Array = [0, 2, 4, 6]
	for ordinal in 4:
		assert_equal(plan.room_field(ordinal, PlanClass.ROOM_COL_TYPE_ID), expected_type_ids[ordinal],
			"room ordinal %d's stored protected room type id" % ordinal)
	assert_true(1 != 2 and 2 != 4 and 3 != 6,
		"room ordinals 1..3 numerically differ from their own stored protected type ids")


func test_pantry_shelves_reach_common_room() -> void:
	var plan := _fresh_plan()
	for i in PANTRY_SOLE_COMMON_ROWS.size():
		var row: int = PANTRY_SOLE_COMMON_ROWS[i]
		var offset: int = plan.furniture_field(row, PlanClass.FURNITURE_COL_CANDIDATE_OFFSET)
		var count: int = plan.furniture_field(row, PlanClass.FURNITURE_COL_CANDIDATE_COUNT)
		assert_equal(count, 1, "pantry shelf row %d has exactly one candidate" % row)
		assert_equal(plan.candidate_access_tiles[offset], PANTRY_SOLE_COMMON_TILES[i], "pantry shelf row %d candidate" % row)
		assert_equal(_oracle_room_of_local(PANTRY_SOLE_COMMON_TILES[i]), 2,
			"pantry shelf row %d's sole candidate is owned by COMMON" % row)


func test_seats_have_a_vertical_walk_neighbor() -> void:
	var plan := _fresh_plan()
	for row in SEAT_ROWS:
		var origin: int = plan.furniture_field(row, PlanClass.FURNITURE_COL_ORIGIN_LOCAL)
		var offset: int = plan.furniture_field(row, PlanClass.FURNITURE_COL_CANDIDATE_OFFSET)
		var count: int = plan.furniture_field(row, PlanClass.FURNITURE_COL_CANDIDATE_COUNT)
		var has_vertical := false
		for i in count:
			var candidate: int = plan.candidate_access_tiles[offset + i]
			if absi(candidate - origin) == 10:
				has_vertical = true
		assert_true(has_vertical, "seat furniture row %d has a vertical (above/below) walk neighbor" % row)


# --- repeated preparation and refusal-after-success ------------------------------------------------

func test_repeated_preparation_is_byte_identical() -> void:
	var canonical := _fresh_plan()
	var canonical_snapshot := _snapshot_plan(canonical)

	var producer := StarterStructures.new()
	var out := StarterStructures.Plan.new()
	var ok1: bool = producer.prepare_into(out)
	assert_true(ok1, "a second independent preparation must succeed")
	_assert_plan_matches_snapshot(out, canonical_snapshot, "a second independent preparation is byte-identical to the first")

	# Dirty every one of the ten arrays with a distinct sentinel, then re-prepare the SAME
	# producer into the SAME output, and require all ten fully restored, not buildings alone.
	out.buildings[0] = 777
	out.rooms[0] = 777
	out.room_tiles[0] = 777
	out.furniture[0] = 777
	out.footprints[0] = 777
	out.candidate_access_tiles[0] = 777
	out.edges[0] = 777
	out.exit_tiles[0] = 777
	out.bed_furniture_ordinals[0] = 777
	out.header[0] = 777

	var ok2: bool = producer.prepare_into(out)
	assert_true(ok2, "preparation into a previously-dirtied Plan must still succeed")
	_assert_plan_matches_snapshot(out, canonical_snapshot, "a fresh successful preparation fully overwrites every dirtied array")


func test_refusal_after_success_preserves_prior_output() -> void:
	"""One FaultProducer instance, driven success -> injected failure -> success again via the
	test-only fail_mode toggle, proving last_refusal() clears on the later success and the prior
	canonical output survives the failed call in between byte-for-byte."""
	var out := StarterStructures.Plan.new()
	var producer := FaultProducer.new()

	var ok1: bool = producer.prepare_into(out)
	assert_true(ok1, "priming preparation must succeed")
	assert_equal(producer.last_refusal(), StarterStructures.REFUSE_NONE, "last_refusal is empty after a success")
	var prior_snapshot := _snapshot_plan(out)

	producer.fail_mode = true
	var ok2: bool = producer.prepare_into(out)
	assert_false(ok2, "a staged plan that fails validation must not publish")
	assert_equal(producer.last_refusal(), StarterStructures.REFUSE_EXIT_INTERIOR, "the exact injected refusal code")
	_assert_plan_matches_snapshot(out, prior_snapshot, "prior output survives a refused preparation")

	producer.fail_mode = false
	var ok3: bool = producer.prepare_into(out)
	assert_true(ok3, "the same producer instance must succeed again once un-faulted")
	assert_equal(producer.last_refusal(), StarterStructures.REFUSE_NONE, "last_refusal clears after a subsequent success")
	_assert_plan_matches_snapshot(out, prior_snapshot, "the repeated successful preparation is byte-identical to the prior canonical output")


# --- source metadata and private graph helpers ------------------------------------------------------

func test_source_metadata_refusal_is_stable_across_calls() -> void:
	var first: StringName = StarterStructures.source_metadata_refusal()
	var second: StringName = StarterStructures.source_metadata_refusal()
	assert_equal(first, StarterStructures.REFUSE_NONE, "the real compiled source metadata must validate")
	assert_equal(second, first,
		"repeated source metadata validation is idempotent; GDScript consts cannot be mutated at runtime, so no true fault witness is claimed here")
	assert_equal(Catalog.BUILDING_DEFINITION.size(), 30, "BuildingDefinition domain size is unchanged")
	assert_equal(Catalog.FURNITURE_DEFINITION.size(), 9, "FurnitureDefinition domain size is unchanged")


func test_edge_blocks_helper_distinguishes_partition_from_door() -> void:
	var plan := _fresh_plan()
	var door_id: int = Catalog.FURNITURE_DEFINITION["interior_door"]
	# Tiles 4/5 are the real authored (4,5) partition edge, in the DORMITORY/KITCHEN column the
	# fixed layout never furnishes. Bounded counterfactual: block, then relabel as a door, then
	# confirm an unrelated adjacent pair with no authored edge is never blocked.
	assert_equal(plan.edge_field(0, PlanClass.EDGE_COL_TILE_A), 4, "edge 0 is the (4,5) partition")
	assert_true(StarterStructures._edge_blocks(plan, 4, 5), "a partition edge blocks its two tiles")
	plan.set_edge_field(0, PlanClass.EDGE_COL_KIND_ID, door_id)
	assert_false(StarterStructures._edge_blocks(plan, 4, 5), "a door edge does not block its two tiles")
	assert_false(StarterStructures._edge_blocks(plan, 5, 6), "two tiles with no authored edge are never blocked")


func test_neighbour_candidates_helper_rejects_across_a_blocked_partition() -> void:
	var plan := _fresh_plan()
	var occupied: Dictionary = {}
	# footprint index 3 holds local tile 3 (bed row 3's single-tile footprint); its real
	# unblocked neighbour 4 is a legal candidate until a synthetic partition is placed between them.
	var real_candidates: Array = StarterStructures._neighbour_candidates(plan, 3, 1, occupied)
	assert_true(real_candidates.has(4), "tile 3's unblocked neighbour 4 is a legal candidate")
	plan.set_edge_field(0, PlanClass.EDGE_COL_TILE_A, 3)
	plan.set_edge_field(0, PlanClass.EDGE_COL_TILE_B, 4)
	plan.set_edge_field(0, PlanClass.EDGE_COL_KIND_ID, Catalog.FURNITURE_DEFINITION["interior_partition"])
	var blocked_candidates: Array = StarterStructures._neighbour_candidates(plan, 3, 1, occupied)
	assert_false(blocked_candidates.has(4), "a synthetic partition between 3 and 4 removes it from the candidate set")
	# TEST-R02-7: the SAME synthetic edge relabeled back to a door must restore the candidate.
	plan.set_edge_field(0, PlanClass.EDGE_COL_KIND_ID, Catalog.FURNITURE_DEFINITION["interior_door"])
	var reopened_candidates: Array = StarterStructures._neighbour_candidates(plan, 3, 1, occupied)
	assert_true(reopened_candidates.has(4), "relabeling the same synthetic edge as a door restores 4 to the candidate set")


# --- extreme values refuse cleanly, never crash -----------------------------------------------------

func test_extreme_and_out_of_range_values_refuse_without_crashing() -> void:
	var cases: Array = [
		_case("building origin at int64 max wraps into an invalid int32 tile", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_GLOBAL_ORIGIN_TILE, 9223372036854775807), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("building type_id at int32 min", func(p): p.set_building_field(0, PlanClass.BUILDING_COL_TYPE_ID, -2147483648), StarterStructures.REFUSE_BUILDING_LAYOUT),
		_case("room tile at a huge global value", func(p): p.room_tiles[0] = 999999999, StarterStructures.REFUSE_ROOM_LAYOUT),
		_case("furniture origin_local at int32 max", func(p): p.set_furniture_field(0, PlanClass.FURNITURE_COL_ORIGIN_LOCAL, 2147483647), StarterStructures.REFUSE_FURNITURE_LAYOUT),
	]
	_run_case_matrix(cases)
