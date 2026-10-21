extends "res://test/framework/test_case.gd"
## The one pending batch (BUILD-REQ-019/020/021, UI-BUILD-006..009): strokes, the batch-wide Undo/Redo and its
## 32-step limit, Discard all, validity in words per operation, the ledger's reads, Confirm all through a host route,
## and UX-BUILD-T04: none of it touches a store, a reservation or a job. Decision 1871.

const Batch := preload("res://scripts/ui/build_batch.gd")
const BuildCatalog := preload("res://scripts/ui/build_catalog.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const Stroke := preload("res://scripts/ui/build_stroke.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Cells := preload("res://scripts/ui/build_cell_validity.gd")

const KITCHEN: int = 2
const DORMITORY: int = 0
const PANTRY: int = 6
const BOUNDS: Rect2i = Rect2i(0, 0, 128, 128)
const CAPACITY: int = 4096

var _batch: Batch = null
var _submitted: Array = []
var _answers: Array = []


func after_each() -> void:
	"""Let go of the subject: its bound readers close over this suite, which would otherwise keep both alive."""
	_batch = null


func before_each() -> void:
	"""A configured batch over a 128 × 128-cell area."""
	_batch = Batch.new()
	assert_equal(_batch.configure(BuildCatalog.new(), BOUNDS, CAPACITY), &"", "configured")
	_submitted.clear()
	_answers.clear()


func _paint(room_type: int, level: int, from: Vector2i, to: Vector2i) -> int:
	"""One rectangle stroke, released; its validity kind."""
	assert_true(_batch.begin_stroke(room_type, level, from), "stroke begins")
	_batch.extend_stroke(to)
	return _batch.finish_stroke()


func _submit(draft: Draft, level: int, room_type: int) -> Variant:
	"""A host route: records what it was given and answers from `_answers` (ok when empty)."""
	@warning_ignore("integer_division") var cells: int = draft.snapshot().cells.size() / 2
	_submitted.append([cells, level, room_type])
	return _answers.pop_front() if not _answers.is_empty() else {"ok": true, "error": ""}


func test_the_planners_draft_accepts_the_one_metre_grid() -> void:
	"""Pitch 1024 u divides the 2 m furnishing grid (ADR 1055); 768 does not and is refused."""
	var draft: Draft = Draft.new()
	assert_equal(draft.configure(KITCHEN, 1, Batch.PITCH_U, CAPACITY, BOUNDS, false), &"", "1024 accepted")
	assert_equal(Draft.new().configure(KITCHEN, 1, 768, CAPACITY, BOUNDS, false), &"INVALID_PLANNING_GRID", "768 refused")
	assert_equal(Batch.new().configure(BuildCatalog.new(), Rect2i(0, 0, 0, 0), CAPACITY), &"INVALID_PLANNING_BOUNDS",
		"an empty area is refused as the planner refuses it")
	assert_equal(Batch.new().configure(null, BOUNDS, CAPACITY), Batch.REFUSE_NOT_CONFIGURED, "no catalog")


func test_an_empty_batch_has_nothing_to_undo_redo_or_confirm() -> void:
	"""The boundary: no operations, the disabled words, and Confirm all does nothing."""
	assert_equal(_batch.pending_count(), 0, "no changes")
	assert_false(_batch.can_undo() or _batch.can_redo(), "nothing in the history")
	assert_equal(_batch.undo_label(), "Nothing to undo", "Undo's disabled words")
	assert_equal(_batch.redo_label(), "Nothing to redo", "Redo's disabled words")
	assert_false(_batch.undo() or _batch.redo(), "both do nothing")
	assert_equal(_batch.first_invalid(), -1, "nothing invalid")
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([0, 0]), "nothing ordered")
	assert_equal(_submitted.size(), 0, "the route was never called")
	assert_equal(_batch.discard_all(), 0, "nothing discarded")


func test_a_stroke_shows_its_size_and_validity_in_words() -> void:
	"""UI-BUILD-010: "Paint Kitchen 6 × 4 cells (6 m × 4 m); ✓ Can build" (24 cells: the Kitchen's least)."""
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(2, 2)), "begun")
	_batch.extend_stroke(Vector2i(7, 5))
	assert_equal(_batch.stroke_size(), Vector2i(6, 4), "6 × 4")
	assert_equal(_batch.stroke_line(), "Paint Kitchen 6 × 4 cells (6 m × 4 m); ✓ Can build", "the ghost's words")
	assert_equal(_batch.stroke_cells().size(), 48, "24 cells drawn")
	_batch.extend_stroke(Vector2i(5, 5))
	assert_equal(_batch.stroke_line(),
		"Paint Kitchen 4 × 4 cells (4 m × 4 m); ! Blocked: Too small: Kitchen needs at least 24 cells (has 16)", "too small")
	_batch.extend_stroke(Vector2i(9, 2))
	assert_equal(_batch.stroke_kind(), Validity.KIND_NOT_POSSIBLE, "one cell deep")
	assert_equal(_batch.stroke_reason(), Validity.too_narrow(), "too narrow")
	assert_equal(Batch.size_text(Vector2i(17, 6)), "17 × 6 cells (17 m × 6 m)", "SET-BUILD-001 §3's example")


func test_a_stroke_past_the_planning_area_is_not_possible_and_never_clipped() -> void:
	"""The planner refuses an out-of-area stroke whole; it shows X and joins nothing."""
	assert_equal(_paint(KITCHEN, 1, Vector2i(124, 124), Vector2i(130, 127)), Validity.KIND_NOT_POSSIBLE, "outside")
	assert_equal(_batch.pending_count(), 0, "nothing joined")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.outside()), "said why")


func test_strokes_join_the_room_they_touch_and_start_a_new_one_apart() -> void:
	"""BUILD-REQ-004: same type, same level, touching -> one operation; apart -> two; another level -> another."""
	assert_equal(_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(3, 2)), Validity.KIND_CAN_BUILD, "12 cells")
	assert_equal(_paint(DORMITORY, 1, Vector2i(4, 0), Vector2i(5, 2)), Validity.KIND_CAN_BUILD, "shares an edge")
	assert_equal(_batch.pending_count(), 1, "one room")
	assert_equal(_batch.operation_cell_count(0), 18, "18 cells")
	assert_equal(_paint(DORMITORY, 1, Vector2i(10, 10), Vector2i(13, 12)), Validity.KIND_CAN_BUILD, "apart")
	assert_equal(_paint(DORMITORY, 2, Vector2i(0, 0), Vector2i(3, 2)), Validity.KIND_CAN_BUILD, "on level 2")
	assert_equal(_batch.pending_count(), 3, "three rooms")
	assert_equal(_batch.operation_level(2), 2, "the third is on level 2")


func test_a_stroke_over_another_room_type_is_not_possible() -> void:
	"""BUILD-REQ-005, in the table's words."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	assert_equal(_paint(PANTRY, 1, Vector2i(4, 2), Vector2i(8, 6)), Validity.KIND_NOT_POSSIBLE, "overlap")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.overlaps("Kitchen")), "words")
	assert_equal(_paint(PANTRY, 1, Vector2i(6, 0), Vector2i(9, 3)), Validity.KIND_CAN_BUILD, "beside it is fine")
	assert_equal(_paint(PANTRY, 2, Vector2i(0, 0), Vector2i(3, 3)), Validity.KIND_CAN_BUILD, "under it, a level down")


func test_a_stroke_joining_two_planned_rooms_merges_them_into_the_older() -> void:
	"""P-B2 (b), ruled for slice C (decision 1912): a bridge between two pending Dormitories makes one room, the older
	one (lower operation) surviving; one Undo step parts them again, and Redo joins them."""
	_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(3, 2))
	_paint(DORMITORY, 1, Vector2i(6, 0), Vector2i(9, 2))
	assert_equal(_paint(DORMITORY, 1, Vector2i(4, 0), Vector2i(5, 2)), Validity.KIND_CAN_BUILD, "a bridge")
	assert_equal(_batch.pending_count(), 1, "one room")
	assert_equal(_batch.operation_cell_count(0), 30, "12 + 6 + 12 cells in the older")
	assert_equal(_batch.operation_cell_count(1), 0, "the younger emptied")
	assert_equal(_batch.undo_label(), "Undo Paint Dormitory", "one step")
	assert_true(_batch.undo(), "undone")
	assert_equal(_batch.pending_count(), 2, "two rooms again")
	assert_equal(_batch.operation_cell_count(0), 12, "the older as it was")
	assert_equal(_batch.operation_cell_count(1), 12, "the younger as it was")
	assert_true(_batch.redo(), "redone")
	assert_equal(_batch.pending_count(), 1, "joined again")
	assert_equal(_batch.operation_cell_count(0), 30, "all of it")


func test_a_merge_past_a_rooms_most_cells_is_not_possible() -> void:
	"""The merged room is held to the planner's capacity like any stroke."""
	var small: Batch = Batch.new()
	small.configure(BuildCatalog.new(), BOUNDS, 40)
	_paint_on(small, DORMITORY, Vector2i(0, 0), Vector2i(3, 4))
	_paint_on(small, DORMITORY, Vector2i(6, 0), Vector2i(9, 4))
	assert_equal(_paint_on(small, DORMITORY, Vector2i(4, 0), Vector2i(5, 1)), Validity.KIND_NOT_POSSIBLE, "44 > 40")
	assert_equal(small.pending_count(), 2, "both kept apart")


func _paint_on(batch: Batch, room_type: int, from: Vector2i, to: Vector2i) -> int:
	"""One stroke of the batch's tool on level 1 of `batch`, released."""
	assert_true(batch.begin_stroke(room_type, 1, from), "stroke begins")
	batch.extend_stroke(to)
	return batch.finish_stroke()


func test_an_oval_is_painted_as_the_planners_ellipse() -> void:
	"""P-C7 (a): Oval fills the corners' box as modular_draft.gd's ELLIPSE does, and is judged as one room."""
	assert_true(_batch.set_tool(Stroke.TOOL_OVAL), "oval")
	assert_true(_batch.begin_stroke(DORMITORY, 1, Vector2i(0, 0)), "begun")
	_batch.extend_stroke(Vector2i(7, 5))
	assert_equal(_batch.stroke_size(), Vector2i(8, 6), "the box")
	var expected: Dictionary = Footprint.ellipse(0, 0, 8, 6, CAPACITY)
	assert_equal(_batch.stroke_cells(), expected.cells, "the planner's ellipse")
	assert_equal(_batch.finish_stroke(), Validity.KIND_CAN_BUILD, "painted")
	assert_equal(_batch.operation_cells(0), expected.cells, "as drawn")


func test_an_oval_with_one_cell_tips_is_too_narrow() -> void:
	"""BUILD-REQ-002 holds for every shape: an oval whose tips are one cell wide is X."""
	_batch.set_tool(Stroke.TOOL_OVAL)
	_batch.begin_stroke(DORMITORY, 1, Vector2i(0, 0))
	_batch.extend_stroke(Vector2i(6, 2))
	assert_false(Batch.two_by_two(_batch.stroke_cells()), "a 7 × 3 oval has one-cell tips")
	assert_equal(_batch.stroke_reason(), Validity.too_narrow(), "too narrow")
	assert_equal(_batch.finish_stroke(), Validity.KIND_NOT_POSSIBLE, "dropped")


func test_the_paint_brush_stamps_two_by_two_blocks_along_the_drag() -> void:
	"""P-C7 (a): Paint covers each dragged cell's 2 × 2 block, so even a one-cell drag keeps BUILD-REQ-002."""
	_batch.set_tool(Stroke.TOOL_PAINT)
	_batch.begin_stroke(PANTRY, 1, Vector2i(4, 4))
	assert_equal(_batch.stroke_cells(), PackedInt32Array([4, 4, 5, 4, 4, 5, 5, 5]), "one block")
	_batch.extend_stroke(Vector2i(7, 4))
	assert_equal(_batch.stroke_size(), Vector2i(5, 2), "a 5 × 2 run")
	assert_true(Batch.two_by_two(_batch.stroke_cells()), "every cell in a block")
	assert_equal(_batch.finish_stroke(), Validity.KIND_BLOCKED, "10 of the Pantry's 16 cells")
	assert_equal(_batch.operation_cell_count(0), 10, "painted")


func test_erase_takes_pending_cells_out_in_one_step() -> void:
	"""P-C7 (a): Erase removes pending cells of the chosen type only; one Undo step puts them back."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(7, 3))
	_batch.set_tool(Stroke.TOOL_ERASE)
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(6, 0)), "erase begun")
	_batch.extend_stroke(Vector2i(6, 2))
	assert_true(_batch.stroke_erasing(), "erasing")
	assert_equal(_batch.stroke_line(), "Erase Kitchen 2 × 4 cells (2 m × 4 m); %s" % Batch.ERASE_OK, "its words")
	assert_equal(_batch.finish_stroke(), Validity.KIND_CAN_BUILD, "taken out")
	assert_equal(_batch.operation_cell_count(0), 24, "32 less the two columns")
	assert_equal(_batch.undo_label(), "Undo Erase Kitchen", "the step named")
	assert_true(_batch.undo(), "undone")
	assert_equal(_batch.operation_cell_count(0), 32, "back")


func test_erase_over_nothing_of_its_type_is_dropped_in_words() -> void:
	"""The PROPOSAL words: nothing of the chosen type under the brush, so nothing is taken and no step kept."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_batch.set_tool(Stroke.TOOL_ERASE)
	assert_equal(_paint(PANTRY, 1, Vector2i(0, 0), Vector2i(1, 1)), Validity.KIND_NOT_POSSIBLE, "no Pantry here")
	assert_equal(_batch.last_dropped(),
		Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.nothing_to_erase("Pantry")), "said why")
	assert_equal(_batch.history_size(), 1, "no step")
	assert_equal(_batch.operation_cell_count(0), 24, "the Kitchen untouched")


func test_erase_that_would_leave_a_strip_is_refused_with_build_req_006s_words() -> void:
	"""Decision 1880 Q3: never a part one cell wide; the stroke is dropped."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(6, 3))
	_batch.set_tool(Stroke.TOOL_ERASE)
	assert_equal(_paint(KITCHEN, 1, Vector2i(4, 0), Vector2i(4, 2)), Validity.KIND_NOT_POSSIBLE, "leaves x 6 alone")
	assert_equal(_batch.last_dropped(),
		Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.narrow_removal("Kitchen")), "BUILD-REQ-006's words")
	assert_equal(_batch.operation_cell_count(0), 28, "nothing taken")


func test_erase_that_cuts_a_room_in_two_splits_it_and_undo_rejoins() -> void:
	"""BUILD-REQ-003: two pieces are two rooms; the piece with the first cell stays; one step undoes both."""
	_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(9, 2))
	_batch.set_tool(Stroke.TOOL_ERASE)
	assert_equal(_paint(DORMITORY, 1, Vector2i(4, 0), Vector2i(4, 1)), Validity.KIND_CAN_BUILD, "a cut")
	assert_equal(_batch.pending_count(), 2, "two rooms")
	assert_equal(_batch.operation_cell_count(0), 12, "the west piece stays first")
	assert_equal(_batch.operation_cell_count(1), 12, "the east piece is a new room")
	assert_equal(_batch.operation_type(1), DORMITORY, "of the same type")
	assert_true(_batch.undo(), "one step")
	assert_equal(_batch.pending_count(), 1, "one room again")
	assert_equal(_batch.operation_cell_count(0), 30, "whole")
	assert_true(_batch.redo(), "and split again")
	assert_equal(_batch.pending_count(), 2, "two")


func test_components_part_cells_into_four_connected_pieces() -> void:
	"""The split's helper: pieces are canonical, the first cell's piece first; a diagonal is no join."""
	var pieces: Array[PackedInt32Array] = Batch.components(PackedInt32Array([0, 0, 1, 0, 5, 0, 2, 1]))
	assert_equal(pieces.size(), 3, "three pieces")
	assert_equal(pieces[0], PackedInt32Array([0, 0, 1, 0]), "the first")
	assert_equal(Batch.components(PackedInt32Array()).size(), 0, "none from nothing")


func test_set_tool_refuses_an_unknown_tool_and_cancels_a_stroke() -> void:
	"""Four tools; choosing one drops the stroke in progress (it was drawn with the other)."""
	assert_false(_batch.set_tool(Stroke.TOOL_COUNT), "no fifth tool")
	assert_false(_batch.set_tool(-1), "nor a negative one")
	assert_equal(_batch.tool(), Stroke.TOOL_RECTANGLE, "Rectangle by default")
	_batch.begin_stroke(KITCHEN, 1, Vector2i(0, 0))
	assert_true(_batch.set_tool(Stroke.TOOL_PAINT), "Paint")
	assert_false(_batch.stroke_active(), "the stroke dropped")


func test_too_small_operations_stay_but_block_confirm_all_naming_the_first() -> void:
	"""BUILD-REQ-021: a "!" operation stays in the batch; Confirm all names it and orders nothing."""
	assert_equal(_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(3, 3)), Validity.KIND_BLOCKED, "16 of 24")
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(11, 1))
	assert_equal(_batch.pending_count(), 2, "both kept")
	assert_equal(_batch.first_invalid(), 0, "the Kitchen first")
	assert_equal(_batch.invalid_count(), 2, "and the 4-cell Pantry")
	assert_equal(_batch.operation_line(0), "Kitchen (+16 cells): ! Blocked: Too small: Kitchen needs at least 24 cells (has 16)",
		"the operation in words")
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([0, 0]), "nothing ordered while invalid")
	assert_equal(_submitted.size(), 0, "the route is not called")
	_paint(KITCHEN, 1, Vector2i(0, 4), Vector2i(3, 5))
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "grown to 24")
	assert_equal(_batch.first_invalid(), 1, "the Pantry now")


func test_undo_and_redo_step_through_the_batch() -> void:
	"""One batch-wide history: undo the last stroke, whichever room it painted; redo it; a new stroke clears Redo."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_paint(KITCHEN, 1, Vector2i(0, 4), Vector2i(5, 5))
	assert_equal(_batch.undo_label(), "Undo Paint Kitchen", "the last step")
	assert_true(_batch.undo(), "undone")
	assert_equal(_batch.operation_cell_count(0), 24, "the Kitchen's second stroke undone")
	assert_equal(_batch.redo_label(), "Redo Paint Kitchen", "redo names it")
	assert_true(_batch.undo(), "undone again")
	assert_equal(_batch.pending_count(), 1, "the Pantry undone: one change left")
	assert_true(_batch.redo(), "redone")
	assert_equal(_batch.pending_count(), 2, "the Pantry is back")
	_paint(DORMITORY, 1, Vector2i(30, 30), Vector2i(33, 32))
	assert_false(_batch.can_redo(), "a new stroke clears Redo")
	assert_equal(_batch.redo_label(), "Nothing to redo", "and says so")


func test_undo_first_drops_the_stroke_in_progress() -> void:
	"""UI §5 tool_undo: "Undo the current stroke, else the last pending build operation"."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_batch.begin_stroke(KITCHEN, 1, Vector2i(0, 4))
	assert_equal(_batch.undo_label(), "Undo the stroke in progress", "the stroke first")
	assert_false(_batch.can_redo(), "no redo during a stroke")
	assert_true(_batch.undo(), "the stroke dropped")
	assert_false(_batch.stroke_active(), "no stroke")
	assert_equal(_batch.pending_count(), 1, "the Kitchen stays")
	assert_true(_batch.undo(), "then the Kitchen")
	assert_equal(_batch.pending_count(), 0, "empty")


func test_the_history_keeps_at_most_32_steps() -> void:
	"""ADR 1055's limit, batch-wide: 33 strokes keep 32 undo steps; undoing all 32 leaves the first stroke."""
	for k: int in 33:
		_paint(DORMITORY, 1, Vector2i(0, 2 * k), Vector2i(5, 2 * k + 1))
	assert_equal(_batch.history_size(), Batch.HISTORY_LIMIT, "32 steps")
	var undone: int = 0
	while _batch.undo():
		undone += 1
	assert_equal(undone, Batch.HISTORY_LIMIT, "32 undos")
	assert_equal(_batch.pending_count(), 1, "the first stroke is past the limit and stays")
	assert_equal(_batch.operation_cell_count(0), 12, "as it was painted")
	for k: int in Batch.HISTORY_LIMIT:
		assert_true(_batch.redo(), "redo %d" % k)
	assert_false(_batch.redo(), "and no more")
	assert_equal(_batch.operation_cell_count(0), 33 * 12, "every stroke back")


func test_discard_all_drops_everything_and_says_how_many() -> void:
	"""UI-BUILD-009: the pending changes and the history go; nothing else does."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 2, Vector2i(0, 0), Vector2i(3, 3))
	assert_equal(_batch.discard_all(), 2, "two dropped")
	assert_equal(_batch.pending_count(), 0, "none left")
	assert_equal(_batch.operation_count(), 0, "no operations")
	assert_false(_batch.can_undo(), "no history")


func test_the_ledger_reads_cells_per_type_in_order() -> void:
	"""One line per room type, in order of first appearance, summed over levels."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_paint(KITCHEN, 2, Vector2i(0, 0), Vector2i(5, 3))
	var types: PackedInt32Array = PackedInt32Array()
	var cells: PackedInt32Array = PackedInt32Array()
	_batch.type_cells_into(types, cells)
	assert_equal(types, PackedInt32Array([KITCHEN, PANTRY]), "Kitchen then Pantry")
	assert_equal(cells, PackedInt32Array([48, 16]), "two Kitchens' cells together")
	assert_equal(_batch.total_cells(), 64, "64 cells")


func test_confirm_all_orders_valid_operations_and_keeps_a_refused_one_with_its_reason() -> void:
	"""BUILD-REQ-019: each operation through the route in order; ordered ones leave and Undo cannot reach them."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_answers = [{"ok": true, "error": ""}, {"ok": false, "error": "Connect a completed passage first."}]
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([1, 1]), "one ordered, one refused")
	assert_equal(_submitted, [[24, 1, KITCHEN], [16, 1, PANTRY]], "in batch order, with level and type")
	assert_equal(_batch.pending_count(), 1, "the Pantry stays")
	assert_equal(_batch.operation_type(0), PANTRY, "and only it")
	assert_equal(_batch.operation_reason(0), "Connect a completed passage first.", "with the route's words")
	assert_equal(_batch.operation_kind(0), Validity.KIND_BLOCKED, "as ! Blocked")
	assert_true(_batch.undo(), "undo reaches the Pantry")
	assert_false(_batch.undo(), "but never the ordered Kitchen")


func test_a_kept_refusal_clears_when_the_operation_changes() -> void:
	"""The route's reason holds until the player repaints the room."""
	_paint(PANTRY, 1, Vector2i(0, 0), Vector2i(3, 3))
	_answers = [{"ok": false, "error": ""}]
	_batch.confirm_all(_submit)
	assert_equal(_batch.operation_reason(0), Batch.UNCHECKED, "a wordless refusal still says something")
	_paint(PANTRY, 1, Vector2i(4, 0), Vector2i(5, 3))
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "repainted: judged again")
	_answers = ["not a dictionary"]
	_batch.confirm_all(_submit)
	assert_equal(_batch.operation_reason(0), Batch.UNCHECKED, "a malformed answer is a refusal")


func test_two_by_two_is_build_req_002() -> void:
	"""Every cell inside some 2 × 2 block: an L of 2-wide arms passes, a 1-wide tail fails."""
	assert_true(Batch.two_by_two(PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])), "a 2 × 2 block")
	assert_false(Batch.two_by_two(PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 1, 1])), "a 1-wide tail")
	assert_true(Batch.two_by_two(PackedInt32Array()), "nothing to fail")


func test_the_batch_holds_no_owner_reference() -> void:
	"""UX-BUILD-T04's structural half: the batch references no Node and no owner at all (the actual owners' bytes,
	reservations and jobs are checked unchanged across painting, Undo, Discard and Confirm all in
	test_demo_build_orders.gd)."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_batch.undo()
	_batch.redo()
	_batch.discard_all()
	for property: Dictionary in _batch.get_property_list():
		var value: Variant = _batch.get(property.name)
		assert_false(value is Node, "%s is no Node" % property.name)


func test_shape_words_are_the_planners_in_plain_words() -> void:
	"""Every code modular_draft.gd returns has words; an unknown one still says something."""
	for code: StringName in Batch.SHAPE_WORDS:
		assert_false(Batch.shape_words(code).is_empty(), String(code))
	assert_false(Batch.shape_words(&"SOMETHING_NEW").is_empty(), "unknown")


func test_one_cell_wide_either_way_is_too_narrow() -> void:
	"""BUILD-REQ-002 in both axes: 1 × 6 and 6 × 1 are not possible; 2 × 6 is."""
	assert_equal(_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(0, 5)), Validity.KIND_NOT_POSSIBLE, "one wide in x")
	assert_equal(_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(5, 0)), Validity.KIND_NOT_POSSIBLE, "one deep in z")
	assert_equal(_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(1, 5)), Validity.KIND_CAN_BUILD, "two wide")


func test_a_stroke_over_its_own_room_counts_the_union_once() -> void:
	"""Growing a Pantry of 8 cells with a 12-cell stroke over those 8: 12 cells, still under the 16 it needs."""
	_paint(PANTRY, 1, Vector2i(0, 0), Vector2i(1, 3))
	assert_true(_batch.begin_stroke(PANTRY, 1, Vector2i(0, 0)), "begun")
	_batch.extend_stroke(Vector2i(2, 3))
	assert_equal(_batch.stroke_reason(), Validity.too_small("Pantry", 16, 12), "the union, not the sum")
	assert_equal(_batch.finish_stroke(), Validity.KIND_BLOCKED, "kept, blocked")
	assert_equal(_batch.operation_cell_count(0), 12, "one room of 12 cells")


func test_a_stroke_inside_its_own_room_adds_nothing_and_no_undo_step() -> void:
	"""Review H1: Kitchen 6×4, Dormitory 6×6, a 3×2 Kitchen stroke inside the Kitchen: dropped, words, no step; the
	first Undo then removes the Dormitory, never the Kitchen."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(DORMITORY, 1, Vector2i(10, 0), Vector2i(15, 5))
	var steps: int = _batch.history_size()
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(1, 1)), "begun")
	_batch.extend_stroke(Vector2i(3, 2))
	assert_equal(_batch.stroke_reason(), Validity.nothing_new(), "nothing to add, before release")
	assert_equal(_batch.stroke_kind(), Validity.KIND_NOT_POSSIBLE, "never ✓")
	assert_equal(_batch.finish_stroke(), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.nothing_new()), "said why")
	assert_equal(_batch.history_size(), steps, "no phantom step")
	assert_true(_batch.undo(), "Undo")
	assert_equal(_batch.operation_cell_count(0), 24, "the Kitchen is untouched")
	assert_equal(_batch.pending_count(), 1, "the Dormitory went")


func test_a_room_past_the_capacity_is_not_possible_and_records_nothing() -> void:
	"""Review H1: a stroke whose room would pass a room's most cells is X before release and joins nothing."""
	var small: Batch = Batch.new()
	assert_equal(small.configure(BuildCatalog.new(), BOUNDS, 40), &"", "a 40-cell capacity")
	small.begin_stroke(KITCHEN, 1, Vector2i(0, 0))
	small.extend_stroke(Vector2i(5, 3))
	assert_equal(small.finish_stroke(), Validity.KIND_CAN_BUILD, "24 cells")
	small.begin_stroke(KITCHEN, 1, Vector2i(0, 4))
	small.extend_stroke(Vector2i(5, 7))
	assert_equal(small.stroke_kind(), Validity.KIND_NOT_POSSIBLE, "48 > 40")
	assert_equal(small.stroke_reason(), Validity.shape(Batch.shape_words(&"FOOTPRINT_CAPACITY")), "in words")
	assert_equal(small.finish_stroke(), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_equal(small.history_size(), 1, "one step only")
	assert_equal(small.operation_cell_count(0), 24, "unchanged")
	small.begin_stroke(KITCHEN, 1, Vector2i(20, 20))
	small.extend_stroke(Vector2i(27, 25))
	assert_equal(small.stroke_kind(), Validity.KIND_NOT_POSSIBLE, "a new room past it too")


func test_redo_never_names_a_confirmed_room() -> void:
	"""Review M2 / BUILD-REQ-020: undone, then confirmed, a room leaves Redo too."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(KITCHEN, 1, Vector2i(0, 4), Vector2i(5, 5))
	_batch.undo()
	assert_true(_batch.can_redo(), "a redo step on the Kitchen")
	_batch.confirm_all(_submit)
	assert_false(_batch.can_redo(), "the confirmed Kitchen is out of Redo's reach")
	assert_equal(_batch.redo_label(), "Nothing to redo", "and Redo says so")


func test_a_ring_with_a_hole_is_blocked_while_drawn_and_after() -> void:
	"""Review M2: four rectangles round a gap make FOOTPRINT_HOLES_NOT_ALLOWED -- never ✓."""
	_paint(PANTRY, 1, Vector2i(0, 0), Vector2i(5, 1))
	_paint(PANTRY, 1, Vector2i(0, 2), Vector2i(1, 5))
	_paint(PANTRY, 1, Vector2i(4, 2), Vector2i(5, 5))
	assert_true(_batch.begin_stroke(PANTRY, 1, Vector2i(2, 4)), "the closing stroke")
	_batch.extend_stroke(Vector2i(3, 5))
	assert_equal(_batch.stroke_kind(), Validity.KIND_BLOCKED, "never ✓ while drawn")
	assert_equal(_batch.stroke_reason(), Validity.shape(Batch.shape_words(&"FOOTPRINT_HOLES_NOT_ALLOWED")), "a hole, in words")
	assert_equal(_batch.finish_stroke(), Validity.KIND_BLOCKED, "kept, blocked")
	assert_equal(_batch.operation_kind(0), Validity.KIND_BLOCKED, "the ring is blocked")
	assert_equal(_batch.operation_reason(0), Validity.shape(Batch.shape_words(&"FOOTPRINT_HOLES_NOT_ALLOWED")), "in words")
	assert_equal(_batch.first_invalid(), 0, "and holds Confirm all back")


func test_confirm_all_and_redo_wait_for_the_stroke_in_progress() -> void:
	"""Review M2: no order and no redo while a stroke is drawn."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_batch.undo()
	assert_equal(_batch.pending_count(), 1, "the Kitchen pending, the Pantry undone")
	_batch.begin_stroke(PANTRY, 1, Vector2i(20, 20))
	assert_false(_batch.redo(), "no redo mid-stroke")
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([0, 0]), "no order mid-stroke")
	assert_equal(_submitted.size(), 0, "the route untouched")


func test_a_route_refusal_is_retried_and_never_holds_confirm_all_back() -> void:
	"""Review H3 (the coordinator's resolution): a "!" route refusal stays in words, is retried by the next Confirm
	all and does not disable it; an "X" one holds it back."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_answers = [{"ok": false, "error": "No way in", "kind": Validity.KIND_BLOCKED},
		{"ok": false, "error": "Cannot dig here: water", "kind": Validity.KIND_NOT_POSSIBLE}]
	_batch.confirm_all(_submit)
	assert_true(_batch.retryable(0), "the Kitchen is retried")
	assert_equal(_batch.operation_line(0), "Kitchen (+24 cells): ! Blocked: No way in", "in words")
	assert_equal(_batch.first_refused(), 0, "the first refused")
	assert_equal(_batch.operation_kind(1), Validity.KIND_NOT_POSSIBLE, "the Pantry: X")
	assert_equal(_batch.first_invalid(), 1, "only the X holds Confirm all back")
	_batch.undo()
	assert_equal(_batch.first_invalid(), -1, "the Pantry undone: nothing holds it back")
	_submitted.clear()
	_answers = [{"ok": true, "error": ""}]
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([1, 0]), "retried and ordered")
	assert_equal(_submitted.size(), 1, "the Kitchen went again")


func test_a_refusal_goes_stale_once_its_room_changes() -> void:
	"""Review H3: a refused room that changes is judged afresh; "too small" again holds Confirm all back, never
	retried as the old refusal."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(3, 3))
	_paint(KITCHEN, 1, Vector2i(4, 0), Vector2i(5, 3))
	_answers = [{"ok": false, "error": "No way in", "kind": Validity.KIND_BLOCKED}]
	_batch.confirm_all(_submit)
	assert_true(_batch.retryable(0), "refused: retried")
	assert_true(_batch.undo(), "the second stroke undone: 16 cells")
	assert_false(_batch.retryable(0), "the old refusal no longer stands")
	assert_equal(_batch.first_invalid(), 0, "too small holds Confirm all back")
	assert_equal(_batch.first_refused(), -1, "nothing to retry")


func test_cells_the_draft_already_holds_are_nothing_to_add() -> void:
	"""Review H1: a stroke over cells the room's draft already holds -- even cells added underneath the batch -- is
	judged against the draft itself and dropped as "Nothing to add", with no Undo step."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	var draft: Draft = _batch.operation_draft(0)
	draft.begin_stroke(Draft.RECTANGLE, Vector2i(6, 0), 0, false)
	draft.extend_stroke(Vector2i(7, 3))
	assert_equal(draft.finish_stroke(), &"", "the draft grown underneath")
	var steps: int = _batch.history_size()
	assert_equal(_paint(KITCHEN, 1, Vector2i(6, 0), Vector2i(7, 3)), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE, Validity.nothing_new()), "in words")
	assert_equal(_batch.history_size(), steps, "no Undo step")


func test_a_stroke_the_draft_refuses_is_dropped_with_its_words() -> void:
	"""Review H1: the planner's own refusal on finish (here its capacity, smaller than the batch was told) drops the
	stroke as "X" with the planner's words, and records nothing."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_batch._capacity = CAPACITY * 4
	var steps: int = _batch.history_size()
	assert_equal(_paint(KITCHEN, 1, Vector2i(0, 4), Vector2i(127, 127)), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_true(_batch.last_dropped().begins_with("X Not possible: Shape: "), _batch.last_dropped())
	assert_equal(_batch.history_size(), steps, "no Undo step")
	assert_equal(_batch.operation_cell_count(0), 24, "the room unchanged")


# --- per cell (decision 1912) -----------------------------------------------------------------------------------

var _ground: Dictionary = {}
var _ground_revision: int = 0


func _bind_ground() -> void:
	"""The fixture's ground: finished space along column 0 of level 1, water where `_ground` says."""
	_ground.clear()
	for z: int in 64:
		_ground[Vector2i(0, z)] = Cells.CELL_FINISHED
	_batch.bind_ground(func(level: int, cell: Vector2i) -> int:
		return int(_ground.get(cell, Cells.CELL_OK)) if level == 1 else Cells.CELL_OK,
		func() -> int: return _ground_revision)


func test_a_room_beside_finished_space_can_be_built_and_one_apart_has_no_way_in() -> void:
	"""BUILD-REQ-013 per cell: beside the finished passage, ✓; apart, "! No way in", which holds Confirm all back
	(it is the batch's own judgement, never a retried route refusal)."""
	_bind_ground()
	assert_equal(_paint(KITCHEN, 1, Vector2i(1, 0), Vector2i(6, 3)), Validity.KIND_CAN_BUILD, "beside it")
	assert_equal(_paint(PANTRY, 1, Vector2i(20, 20), Vector2i(23, 23)), Validity.KIND_BLOCKED, "apart")
	assert_equal(_batch.operation_reason(1), Validity.no_way_in(), "the words")
	assert_equal(_batch.operation_cell_codes(1).count(Cells.CELL_NO_WAY_IN), 16, "every cell")
	assert_equal(_batch.first_invalid(), 1, "it holds Confirm all back")
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([0, 0]), "nothing ordered")
	assert_false(_batch.retryable(1), "not a route refusal")


func test_a_passage_brings_the_way_in_to_the_room_behind_it() -> void:
	"""P-C4 (a): painting a Passage from the finished column to the Pantry gives the Pantry its way in."""
	_bind_ground()
	_paint(PANTRY, 1, Vector2i(8, 0), Vector2i(11, 3))
	assert_equal(_batch.operation_kind(0), Validity.KIND_BLOCKED, "no way in yet")
	assert_equal(_paint(BuildCatalog.CORRIDOR, 1, Vector2i(1, 0), Vector2i(7, 1)), Validity.KIND_CAN_BUILD, "a passage")
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "the Pantry is reached")
	assert_equal(_batch.first_invalid(), -1, "all ready")


func test_a_stroke_over_ground_the_crew_cannot_dig_is_dropped() -> void:
	"""ECON-003 per cell: a stroke covering water is X, its cell codes say which, and it is dropped on release."""
	_bind_ground()
	_ground[Vector2i(3, 1)] = Cells.CELL_WATER
	assert_true(_batch.begin_stroke(KITCHEN, 1, Vector2i(1, 0)), "begun")
	_batch.extend_stroke(Vector2i(6, 3))
	assert_equal(_batch.stroke_reason(), Validity.cannot_dig("water"), "water")
	assert_equal(_batch.stroke_cell_codes().count(Cells.CELL_WATER), 1, "one cell")
	assert_equal(_batch.stroke_cell_codes().size(), 24, "aligned with the stroke's cells")
	assert_equal(_batch.finish_stroke(), Validity.KIND_NOT_POSSIBLE, "dropped")
	assert_equal(_batch.pending_count(), 0, "nothing painted")


func test_a_stroke_with_no_way_in_says_so_while_drawn() -> void:
	"""The stroke's own words name the way in before it is released."""
	_bind_ground()
	_batch.begin_stroke(PANTRY, 1, Vector2i(20, 20))
	_batch.extend_stroke(Vector2i(23, 23))
	assert_equal(_batch.stroke_reason(), Validity.no_way_in(), "no way in")
	assert_equal(_batch.stroke_kind(), Validity.KIND_BLOCKED, "!")


func test_a_ground_change_judges_the_cells_again() -> void:
	"""The ground reader's revision moving re-judges every operation (and bumps the batch's revision for the
	ghosts)."""
	_bind_ground()
	_paint(KITCHEN, 1, Vector2i(1, 0), Vector2i(6, 3))
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "✓")
	_ground[Vector2i(4, 2)] = Cells.CELL_OCCUPIED
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "the same revision: unchanged")
	var seen: int = _batch.revision
	_ground_revision += 1
	assert_equal(_batch.operation_kind(0), Validity.KIND_NOT_POSSIBLE, "judged again")
	assert_equal(_batch.operation_reason(0), Validity.cannot_dig("occupied"), "occupied")
	assert_true(_batch.revision > seen, "the ghosts redraw")


func test_landings_are_handed_to_the_cell_judge() -> void:
	"""bind_landings: a connector landing on level 2 gives a room there its way in."""
	_bind_ground()
	_batch.bind_landings(func(level: int) -> PackedInt32Array: return PackedInt32Array([30, 30]) if level == 2 else PackedInt32Array())
	assert_equal(_paint(PANTRY, 2, Vector2i(29, 29), Vector2i(32, 32)), Validity.KIND_CAN_BUILD, "landed on")
	assert_true(_batch.cell_judge().ground_bound(), "the judge has the ground")


# --- ways down (decision 1912) -------------------------------------------------------------------------------------

func test_an_entrance_gives_level_one_its_way_in_and_orders_first() -> void:
	"""OPEN-07 (a): a pending Entrance's landing is a way in for the room beside it; Confirm all sends the Entrance
	first, then the room; Undo before that takes the Entrance away again."""
	_bind_ground()
	_paint(PANTRY, 1, Vector2i(20, 20), Vector2i(23, 23))
	assert_equal(_batch.operation_reason(0), Validity.no_way_in(), "no way in yet")
	assert_equal(_batch.place_item(0, Vector2i(24, 20)), Validity.KIND_CAN_BUILD, "an Entrance beside it")
	assert_equal(_batch.items().landings(1), PackedInt32Array([24, 20, 25, 20, 24, 21, 25, 21]), "its landing")
	assert_equal(_batch.operation_kind(0), Validity.KIND_CAN_BUILD, "the Pantry is reached")
	assert_equal(_batch.pending_count(), 2, "two changes")
	assert_equal(_batch.undo_label(), "Undo Place Hatch with ladder", "the step named (decision 2021: by family)")
	assert_true(_batch.undo(), "undone")
	assert_equal(_batch.operation_reason(0), Validity.no_way_in(), "no way in again")
	assert_true(_batch.redo(), "redone")
	var order: Array = []
	var result: PackedInt32Array = _batch.confirm_all(func(_d: Draft, level: int, _t: int) -> Dictionary:
		order.append("room %d" % level)
		return {"ok": true}, func(level: int, cell: Vector2i, _family: int, _turn: int, _removal: bool) -> Dictionary:
		order.append("way down %d %s" % [level, cell])
		return {"ok": true})
	assert_equal(order, ["way down 0 (24, 20)", "room 1"], "the way in first")
	assert_equal(result, PackedInt32Array([2, 0]), "both ordered")
	assert_equal(_batch.pending_count(), 0, "none pending")
	assert_false(_batch.can_redo() or _batch.can_undo(), "out of Undo's reach")


func test_a_way_down_is_judged_where_it_stands_and_lands() -> void:
	"""Below the surface it needs a passage or room under it ("!"); it may not land on water, overlap another, stand
	past level 3 or leave the planning area ("X", dropped in words)."""
	_bind_ground()
	assert_equal(_batch.place_item(1, Vector2i(30, 30)), Validity.KIND_BLOCKED, "nothing under it yet")
	assert_equal(_batch.item_reason(0), Validity.needs_passage("Hatch with ladder"), "says so (P-D1-5 (a))")
	assert_equal(_batch.first_invalid_item(), 0, "it holds Confirm all back")
	assert_equal(_batch.invalid_count(), 1, "counted")
	_paint(BuildCatalog.CORRIDOR, 1, Vector2i(30, 30), Vector2i(33, 31))
	assert_equal(_batch.item_kind(0), Validity.KIND_CAN_BUILD, "a Passage under it")
	assert_equal(_batch.place_item(1, Vector2i(31, 30)), Validity.KIND_NOT_POSSIBLE, "overlapping")
	assert_equal(_batch.last_dropped(), Validity.line(Validity.KIND_NOT_POSSIBLE,
		Validity.overlaps_way_down("Hatch with ladder")), "words")
	_ground[Vector2i(40, 40)] = Cells.CELL_WATER
	_batch.bind_ground(func(_level: int, cell: Vector2i) -> int: return int(_ground.get(cell, Cells.CELL_OK)),
		func() -> int: return _ground_revision)
	assert_equal(_batch.place_item(0, Vector2i(39, 39)), Validity.KIND_NOT_POSSIBLE, "landing on water")
	assert_equal(_batch.place_item(4, Vector2i(5, 5)), Validity.KIND_NOT_POSSIBLE, "no level below level 4")
	assert_equal(_batch.place_item(0, Vector2i(127, 5)), Validity.KIND_NOT_POSSIBLE, "past the area")
	_batch.begin_stroke(KITCHEN, 1, Vector2i(60, 60))
	assert_equal(_batch.place_item(0, Vector2i(50, 50)), -1, "not mid-stroke")
	_batch.discard_all()
	assert_equal(_batch.items().count(), 0, "Discard all drops them")


func test_a_merge_past_capacity_reads_x_while_drawn() -> void:
	"""The made room is measured while the stroke is drawn: 44 cells against 43 is X before release (mutation B03)."""
	var small: Batch = Batch.new()
	small.configure(BuildCatalog.new(), BOUNDS, 43)
	_paint_on(small, DORMITORY, Vector2i(0, 0), Vector2i(3, 4))
	_paint_on(small, DORMITORY, Vector2i(6, 0), Vector2i(9, 4))
	small.begin_stroke(DORMITORY, 1, Vector2i(4, 0))
	small.extend_stroke(Vector2i(5, 1))
	assert_equal(small.stroke_kind(), Validity.KIND_NOT_POSSIBLE, "44 of 43 while drawn")
	assert_equal(small.stroke_reason(), Validity.shape(Batch.shape_words(&"FOOTPRINT_CAPACITY")), "in the planner's words")


func test_a_stroke_whose_first_cell_is_water_is_x() -> void:
	"""Even the stroke's very first cell is judged (mutation B04)."""
	_bind_ground()
	_ground[Vector2i(1, 0)] = Cells.CELL_WATER
	_batch.begin_stroke(KITCHEN, 1, Vector2i(1, 0))
	_batch.extend_stroke(Vector2i(6, 3))
	assert_equal(_batch.stroke_reason(), Validity.cannot_dig("water"), "the corner cell")


func test_a_way_down_may_land_on_dug_space() -> void:
	"""A landing on cells already dug (or ordered) joins two levels; only undiggable ground refuses it (B15)."""
	_bind_ground()
	_ground[Vector2i(41, 41)] = Cells.CELL_FINISHED
	assert_equal(_batch.place_item(0, Vector2i(40, 40)), Validity.KIND_CAN_BUILD, "over a dug cell")


func test_a_way_down_with_no_route_for_it_counts_as_refused() -> void:
	"""Confirm all with no route for ways down keeps them and counts them refused (B17)."""
	_batch.place_item(0, Vector2i(10, 10))
	assert_equal(_batch.confirm_all(_submit), PackedInt32Array([0, 1]), "kept, refused")
	assert_equal(_batch.pending_count(), 1, "still pending")


func test_a_kept_refusal_never_covers_a_later_no_way_in() -> void:
	"""Mutation B18: a room the route refused, which then loses its way in (its Entrance undone), holds Confirm all
	back with "No way in" rather than being retried."""
	_bind_ground()
	_batch.place_item(0, Vector2i(24, 20))
	_paint(PANTRY, 1, Vector2i(20, 20), Vector2i(23, 23))
	_answers.append({"ok": false, "error": "refused by the route", "kind": Validity.KIND_BLOCKED})
	_batch.confirm_all(_submit)
	assert_true(_batch.retryable(0), "refused: retried")
	_batch.discard_all()
	_paint(PANTRY, 1, Vector2i(20, 20), Vector2i(23, 23))
	_batch.place_item(0, Vector2i(24, 20))
	_answers.append({"ok": false, "error": "refused by the route", "kind": Validity.KIND_BLOCKED})
	_batch.confirm_all(_submit)
	assert_true(_batch.undo(), "the Entrance undone")
	assert_equal(_batch.operation_reason(0), Validity.no_way_in(), "no way in now")
	assert_false(_batch.retryable(0), "not a retry")
	assert_equal(_batch.first_invalid(), 0, "it holds Confirm all back")


# --- review round (decision 1912) ---------------------------------------------------------------------------------

func test_a_partial_confirm_never_puts_undo_out_of_step() -> void:
	"""Review H1: an erase over two rooms, one then ordered and one refused: nothing older than that step is undone
	into the kept room, and Redo is cleared."""
	_paint(DORMITORY, 1, Vector2i(20, 0), Vector2i(25, 5))
	_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(5, 5))
	_batch.set_tool(Stroke.TOOL_ERASE)
	_paint(DORMITORY, 1, Vector2i(4, 4), Vector2i(20, 4))
	var kept_cells: int = _batch.operation_cell_count(0)
	_answers.append({"ok": false, "error": "refused", "kind": Validity.KIND_BLOCKED})
	_batch.confirm_all(_submit)
	assert_equal(_batch.pending_count(), 1, "the refused room kept")
	assert_false(_batch.can_undo(), "nothing older than the ordered step can be undone")
	assert_false(_batch.can_redo(), "and no Redo")
	assert_equal(_batch.operation_cell_count(0), kept_cells, "the kept room as it was")


func test_a_prune_with_a_way_down_step_in_the_history_keeps_its_row() -> void:
	"""M1: a pruned room renumbers the room entries only; the way down's entry keeps its row."""
	_paint(KITCHEN, 1, Vector2i(0, 0), Vector2i(5, 3))
	_batch.place_item(0, Vector2i(30, 30))
	_paint(PANTRY, 1, Vector2i(10, 0), Vector2i(13, 3))
	_batch.undo()
	_batch.undo()
	_batch.undo()
	_paint(PANTRY, 2, Vector2i(10, 0), Vector2i(13, 3))
	assert_equal(_batch.items().live_count(), 0, "the way down undone and its step cleared")
	assert_equal(_batch.operation_count(), 1, "the emptied rooms pruned")
	assert_equal(_batch.undo_label(), "Undo Paint Pantry", "the new step")


func test_an_erase_into_three_pieces_keeps_the_first_cells_piece() -> void:
	"""M1: two cuts make three rooms; the piece with the room's first cell stays the room."""
	_paint(DORMITORY, 1, Vector2i(0, 0), Vector2i(13, 2))
	_batch.set_tool(Stroke.TOOL_PAINT)
	_batch.set_tool(Stroke.TOOL_ERASE)
	_batch.begin_stroke(DORMITORY, 1, Vector2i(4, 0))
	_batch.extend_stroke(Vector2i(4, 1))
	_batch.finish_stroke()
	_batch.begin_stroke(DORMITORY, 1, Vector2i(9, 0))
	_batch.extend_stroke(Vector2i(9, 1))
	_batch.finish_stroke()
	assert_equal(_batch.pending_count(), 3, "three rooms")
	assert_equal(_batch.operation_cells(0)[0], 0, "the first room starts at x 0")
	assert_equal(_batch.operation_cell_count(0), 12, "and is the west piece")


func test_a_way_down_stands_on_dug_space() -> void:
	"""M1: a Way down over dug (ground FINISHED) cells needs no pending room under it."""
	_bind_ground()
	for cell: Vector2i in [Vector2i(50, 50), Vector2i(51, 50), Vector2i(50, 51), Vector2i(51, 51)]:
		_ground[cell] = Cells.CELL_FINISHED
	_ground_revision += 1
	assert_equal(_batch.place_item(1, Vector2i(50, 50)), Validity.KIND_CAN_BUILD, "on dug space")
