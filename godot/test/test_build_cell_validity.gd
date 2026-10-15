extends "res://test/framework/test_case.gd"
## Validity per cell (decision 1912, slice C1): the ground the crew can dig (ECON-003), the 2 × 2 rule
## (BUILD-REQ-002) and the way in (BUILD-REQ-013, decision 1911 P-C4 (a): through drafted cells of any type to finished
## space or a connector's landing), each cell's code in the canonical words.

const Cells := preload("res://scripts/ui/build_cell_validity.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")

const BOUNDS: Rect2i = Rect2i(0, 0, 32, 32)

var _cells: Cells = null
## Ground readings by cell (absent: CELL_OK), and the reader's revision.
var _ground: Dictionary = {}
var _revision: int = 0
var _landing: PackedInt32Array = PackedInt32Array()
var _asked_levels: PackedInt32Array = PackedInt32Array()


func after_each() -> void:
	"""Let go of the subject: its bound readers close over this suite, which would otherwise keep both alive."""
	_cells = null


func before_each() -> void:
	"""A judge over a 32 × 32-cell area with the fixture's ground reader bound."""
	_cells = Cells.new()
	assert_equal(_cells.configure(BOUNDS), &"", "configured")
	_ground.clear()
	_landing = PackedInt32Array()
	_asked_levels.clear()
	_cells.bind_ground(_read, func() -> int: return _revision)


func _read(level: int, cell: Vector2i) -> int:
	"""The fixture's ground: what `_ground` says, else diggable."""
	if not _asked_levels.has(level):
		_asked_levels.append(level)
	return int(_ground.get(cell, Cells.CELL_OK))


static func _rect(x: int, z: int, width: int, depth: int) -> PackedInt32Array:
	"""A canonical rectangle of cells (row-major: z, then x)."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in range(z, z + depth):
		for column: int in range(x, x + width):
			out.append_array(PackedInt32Array([column, row]))
	return out


func _finished_column(x: int, from_z: int, to_z: int) -> void:
	"""A finished passage along column x."""
	for z: int in range(from_z, to_z + 1):
		_ground[Vector2i(x, z)] = Cells.CELL_FINISHED


func test_configure_refuses_an_empty_area() -> void:
	"""The scratch is sized to the planning area once; an empty one is refused."""
	assert_equal(Cells.new().configure(Rect2i(0, 0, 0, 4)), Cells.REFUSE_BOUNDS, "empty")
	assert_equal(Cells.new().configure(Rect2i(0, 0, 2048, 2048)), Cells.REFUSE_BOUNDS, "past a million cells")


func test_a_room_beside_finished_space_has_a_way_in() -> void:
	"""Every cell of a room touching a finished passage is reached: all CELL_OK."""
	_finished_column(3, 0, 10)
	var room: PackedInt32Array = _rect(4, 2, 4, 3)
	var codes: Array[PackedByteArray] = _cells.judge_level(1, [room])
	assert_equal(codes[0], _all(12, Cells.CELL_OK), "all can be built")
	assert_equal(_asked_levels, PackedInt32Array([1]), "the ground read on the level judged")


func test_a_room_with_nothing_finished_near_has_no_way_in() -> void:
	"""BUILD-REQ-013: no route to finished space: every cell "! No way in"."""
	var codes: Array[PackedByteArray] = _cells.judge_level(1, [_rect(4, 2, 4, 3)])
	assert_equal(codes[0], _all(12, Cells.CELL_NO_WAY_IN), "no way in")
	assert_equal(Cells.kind_of(Cells.CELL_NO_WAY_IN), Validity.KIND_BLOCKED, "!")
	assert_equal(Cells.words_of(Cells.CELL_NO_WAY_IN), Validity.no_way_in(), "the canonical words")


func test_the_way_in_runs_through_a_drafted_passage_of_another_type() -> void:
	"""P-C4 (a): a room reached through a drafted Passage (another set) has a way in; one beyond a gap has none."""
	_finished_column(0, 0, 4)
	var passage: PackedInt32Array = _rect(1, 0, 6, 2)
	var room: PackedInt32Array = _rect(7, 0, 4, 4)
	var apart: PackedInt32Array = _rect(13, 0, 4, 4)
	var codes: Array[PackedByteArray] = _cells.judge_level(1, [passage, room, apart])
	assert_equal(codes[0], _all(12, Cells.CELL_OK), "the passage")
	assert_equal(codes[1], _all(16, Cells.CELL_OK), "the room through it")
	assert_equal(codes[2], _all(16, Cells.CELL_NO_WAY_IN), "the room past the gap")


func test_a_connector_landing_is_a_way_in() -> void:
	"""OPEN-07 (a): a built or drafted connector's landing seeds the way in (slice D's reader)."""
	_cells.bind_landings(func(level: int) -> PackedInt32Array: return PackedInt32Array([5, 5]) if level == 2 else PackedInt32Array())
	var room: PackedInt32Array = _rect(4, 4, 4, 4)
	assert_equal(_cells.judge_level(2, [room])[0], _all(16, Cells.CELL_OK), "landed on")
	assert_equal(_cells.judge_level(1, [room])[0], _all(16, Cells.CELL_NO_WAY_IN), "not on another level")


func test_a_cell_that_cannot_be_dug_is_x_and_carries_no_way_in() -> void:
	"""ECON-003 per cell: water, protected ground, occupied and a protected route, in the table's words; such a cell
	never carries the way in to the cells behind it."""
	_finished_column(0, 0, 1)
	_ground[Vector2i(1, 0)] = Cells.CELL_WATER
	_ground[Vector2i(1, 1)] = Cells.CELL_WATER
	var room: PackedInt32Array = _rect(1, 0, 4, 2)
	var codes: PackedByteArray = _cells.judge_level(1, [room])[0]
	assert_equal(codes[0], Cells.CELL_WATER, "water")
	assert_equal(codes[1], Cells.CELL_NO_WAY_IN, "behind the water: no way in")
	assert_equal(Cells.words_of(Cells.CELL_WATER), Validity.cannot_dig("water"), "the words")
	assert_equal(Cells.words_of(Cells.CELL_PROTECTED), Validity.cannot_dig("protected ground"), "protected")
	assert_equal(Cells.words_of(Cells.CELL_OCCUPIED), Validity.cannot_dig("occupied"), "occupied")
	assert_equal(Cells.words_of(Cells.CELL_ROUTE), Validity.cannot_dig("protected route"), "route")
	assert_equal(Cells.kind_of(Cells.CELL_WATER), Validity.KIND_NOT_POSSIBLE, "X")
	assert_equal(Cells.words_of(Cells.CELL_OK), "", "no words for a good cell")


func test_drafting_over_finished_space_is_occupied() -> void:
	"""A drafted cell already dug is "occupied", never a second dig."""
	_finished_column(2, 0, 3)
	var codes: PackedByteArray = _cells.judge_level(1, [_rect(2, 0, 2, 2)])[0]
	assert_equal(codes[0], Cells.CELL_OCCUPIED, "dug already")
	assert_equal(codes[1], Cells.CELL_OK, "its neighbour is beside finished space")


func test_a_one_cell_strip_is_too_narrow_per_cell_and_still_carries_the_way_in() -> void:
	"""BUILD-REQ-002 per cell: only the strip's cells are X; it is diggable, so the room past it is reached."""
	_finished_column(0, 0, 3)
	var room: PackedInt32Array = PackedInt32Array([1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 1, 1, 2, 1])
	var codes: PackedByteArray = _cells.judge_level(1, [room])[0]
	assert_equal(codes, PackedByteArray([0, 0, 1, 1, 1, 0, 0]), "x 3-5 in no 2 × 2 block")
	assert_equal(Cells.words_of(Cells.CELL_TOO_NARROW), Validity.too_narrow(), "the words")


func test_a_cell_outside_the_area_is_protected_ground() -> void:
	"""Past the planning area there is no ground to dig."""
	var codes: PackedByteArray = _cells.judge_level(1, [PackedInt32Array([31, 31, 32, 31])])[0]
	assert_equal(codes[1], Cells.CELL_PROTECTED, "outside")


func test_without_a_ground_reader_only_the_two_by_two_rule_is_judged() -> void:
	"""A host that knows no ground claims nothing about it."""
	var bare: Cells = Cells.new()
	bare.configure(BOUNDS)
	assert_false(bare.ground_bound(), "unbound")
	assert_equal(bare.ground_revision(), 0, "revision 0")
	assert_equal(bare.judge_level(1, [_rect(4, 4, 2, 2)])[0], _all(4, Cells.CELL_OK), "no way-in claim")
	assert_true(_cells.ground_bound(), "the fixture's is bound")
	_revision = 7
	assert_equal(_cells.ground_revision(), 7, "the reader's revision")


func test_the_scratch_is_clean_after_each_judgement() -> void:
	"""Sets judged together are independent of the next judgement: a room judged alone after a merge-free pair is
	judged afresh, and the count of judgements grows by one each time."""
	_finished_column(0, 0, 3)
	var first: int = _cells.judgements
	_cells.judge_level(1, [_rect(1, 0, 2, 2)])
	var codes: PackedByteArray = _cells.judge_level(1, [_rect(10, 10, 2, 2)])[0]
	assert_equal(codes, _all(4, Cells.CELL_NO_WAY_IN), "nothing left over from the last")
	assert_equal(_cells.judgements, first + 2, "two judgements")


static func _all(count: int, code: int) -> PackedByteArray:
	"""`count` copies of `code`."""
	var out: PackedByteArray = PackedByteArray()
	out.resize(count)
	out.fill(code)
	return out


func test_the_way_in_runs_through_a_one_cell_strip_to_the_block_beyond() -> void:
	"""A strip one cell wide is still dug, so it carries the way in to the block past it (mutation C04)."""
	_finished_column(0, 0, 3)
	var room: PackedInt32Array = PackedInt32Array([1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 1, 1, 2, 1, 6, 1, 7, 1])
	var codes: PackedByteArray = _cells.judge_level(1, [room])[0]
	assert_equal(codes, PackedByteArray([0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0]), "the far block reached")
